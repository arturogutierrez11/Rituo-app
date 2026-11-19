#!/usr/bin/env python3
"""Run the production scheduler with an in-memory 20-slot DeviceActivity adapter.

Verifies preservation and rollback; does not emulate iOS callback timing.
"""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'HolaSwift/Services/DeviceActivityScheduler.swift').read_text().split('/// DeviceActivity IPC')[0]
source=source.replace('import DeviceActivity\n','').replace('import FamilyControls\n','').replace('final class DeviceActivityScheduler {','@MainActor final class DeviceActivityScheduler {')
metadata=(root/'HolaSwift/Services/SharedRitualActivityMetadataStore.swift').read_text().split('struct SharedRitualActivityMetadataStore')[0]
fixtures=r'''
import Foundation
struct DeviceActivityName: Hashable { let rawValue: String; init(_ name: String) { rawValue=name } }
struct FamilyActivitySelection: Codable {
 var applicationTokens=["token"]; var categoryTokens:[String]=[]; var webDomainTokens:[String]=[]
}
struct RitualScheduler {
 let id: UUID; var title: String; var weekdays=Array(1...7)
 let selectedItemCount=1; var startHour:Int; var endHour:Int
 let startMinute=0; let endMinute=0; let coreRitualId:String?=nil
 var selection=FamilyActivitySelection(); let strictModeEnabled=false
 let blockAppInstallation=false; let blockAdultContent=false
 var durationMinutes:Int { ((endHour-startHour)+24)%24*60 }
 var crossesMidnight:Bool { endHour<startHour }
 func endDate()->Date? { Date(timeIntervalSince1970: 2_000_000_000) }
}
@MainActor final class Fixture {
 static let shared=Fixture()
 var registrations:[String:RitualMonitorRegistration]=[:]
 var selections:[String:FamilyActivitySelection]=[:]
 var metadata:[String:SharedRitualActivityMetadata]=[:]
 var active=Set<String>(); var stopped:[String]=[]; var attempts=0; var clears=0
 var failingAttempts=Set<Int>(); var writeBeforeFailure=false
 var failMetadataOnce:String?
}
@MainActor struct SharedRitualSelectionStore {
 func save(selection:FamilyActivitySelection,for name:String)throws { Fixture.shared.selections[name]=selection }
 func loadSelection(for name:String)->FamilyActivitySelection? { Fixture.shared.selections[name] }
 func removeSelection(for name:String) { Fixture.shared.selections[name]=nil }
}
@MainActor struct SharedRitualActivityMetadataStore {
 func save(metadata:SharedRitualActivityMetadata,for name:String)throws {
  if Fixture.shared.failMetadataOnce == name { Fixture.shared.failMetadataOnce=nil; throw DeviceActivityMonitorExecutor.Failure.interrupted }
  Fixture.shared.metadata[name]=metadata
 }
 func loadMetadata(for name:String)->SharedRitualActivityMetadata? { Fixture.shared.metadata[name] }
 func removeMetadata(for name:String) { Fixture.shared.metadata[name]=nil }
}
@MainActor struct SharedRitualActivityStateStore {
 func clear() { Fixture.shared.active=[]; Fixture.shared.clears+=1 }
 func remove(activityName:String) { Fixture.shared.active.remove(activityName) }
}
struct DeviceActivityDebugStore { func log(_ message:String) {} }
@MainActor final class AppDiagnostics {
 static let shared=AppDiagnostics()
 func begin(_ name:String)->Int { 0 }; func end(_ name:String,_ span:Int) {}
}
@MainActor final class DeviceActivityMonitorExecutor {
 enum Failure:Error { case capacity,interrupted }
 func names()async->Set<String> { Set(Fixture.shared.registrations.keys) }
 func registration(_ name:String)async->RitualMonitorRegistration? { Fixture.shared.registrations[name] }
 func register(_ name:String,registration:RitualMonitorRegistration)async throws {
  let f=Fixture.shared; f.attempts+=1
  if f.failingAttempts.contains(f.attempts) {
   if f.writeBeforeFailure { f.registrations[name]=registration }
   throw Failure.interrupted
  }
  if f.registrations[name] == nil && f.registrations.count>=20 { throw Failure.capacity }
  f.registrations[name]=registration
 }
 func stop(_ names:[String])async {
  let f=Fixture.shared; f.stopped+=names
  // Match Apple's API: [] stops ALL activities, including auxiliary timers.
  if names.isEmpty { f.registrations.removeAll(); return }
  for name in names { f.registrations[name]=nil }
 }
}
'''
tests=r'''
@main struct Tests {
 @MainActor static func main()async {
  let suite="rituo.schedule.safety."+UUID().uuidString
  let defaults=UserDefaults(suiteName:suite)!
  defer { defaults.removePersistentDomain(forName:suite) }
  let scheduler=DeviceActivityScheduler(defaults:defaults)
  let f=Fixture.shared
  let a=RitualScheduler(id:UUID(),title:"05-20",startHour:5,endHour:20)
  let b=RitualScheduler(id:UUID(),title:"07-13",startHour:7,endHour:13)
  let c=RitualScheduler(id:UUID(),title:"07-13 copy",startHour:7,endHour:13)
  func name(_ r:RitualScheduler,_ day:Int=1)->String { "rituo.ritual.\(r.id.uuidString).weekday.\(day)" }
  func schedule(_ rituals:[RitualScheduler])async->Error? {
   await withCheckedContinuation { done in scheduler.reschedule(rituals,userID:"test") { done.resume(returning:$0) } }
  }
  func bytes(_ metadata:[String:SharedRitualActivityMetadata])->[String:Data] {
   let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
   return metadata.mapValues { try! encoder.encode($0) }
  }
  // Migrate a full legacy weekly registry, reusing legacy anchors without extra slots.
  for r in [a,b] { for day in 1...7 {
   let n=name(r,day)
   f.registrations[n]=RitualMonitorRegistration(
    start:DateComponents(calendar:.current,hour:r.startHour,minute:0,weekday:day),
    end:DateComponents(calendar:.current,hour:r.endHour,minute:0,weekday:day),repeats:true,warning:DateComponents(minute:2))
   f.selections[n]=r.selection
   f.metadata[n]=SharedRitualActivityMetadata(activityName:n,userID:"test",schedulerId:r.id.uuidString,
    coreRitualId:nil,title:r.title,plannedEndAt:r.endDate(),endHour:r.endHour,endMinute:0)
  }}
  defaults.set(Array(f.registrations.keys),forKey:"rituo.deviceActivity.scheduledNames")
  f.active=[name(a),name(b)]
  let migrated=await schedule([a,b,c]);precondition(migrated == nil)
  precondition(f.registrations.count==3 && f.clears==0)
  precondition(f.registrations.values.allSatisfy { $0.start.weekday == nil && $0.end.weekday == nil })
  precondition(f.active == Set([name(a),name(b)]))
  let starts=f.attempts;let stops=f.stopped.count
  let same=await schedule([a,b,c]);precondition(same == nil)
  precondition(f.attempts==starts && f.stopped.count==stops)
  print("PASS: three daily rituals use 3 slots; legacy migration; unchanged/NFC plan retains active monitors")

  let old=f.registrations;let oldMetadata=bytes(f.metadata);let oldFingerprint=defaults.string(forKey:"rituo.deviceActivity.scheduleFingerprint")
  var changedA=a;changedA.startHour=6;changedA.title="edited"
  var changedB=b;changedB.startHour=8
  f.failingAttempts=[f.attempts+2];f.writeBeforeFailure=true
  let failed=await schedule([changedA,changedB,c]);precondition(failed != nil)
  precondition(f.registrations==old && bytes(f.metadata)==oldMetadata)
  precondition(defaults.string(forKey:"rituo.deviceActivity.scheduleFingerprint")==oldFingerprint)
  precondition(f.clears==0 && f.active == Set([name(a),name(b)]))
  print("PASS: partial failure restores original native schedules, metadata, fingerprint and active state")

  let d=RitualScheduler(id:UUID(),title:"new",startHour:9,endHour:14)
  f.failingAttempts=[f.attempts+1]
  let failedNew=await schedule([a,b,c,d]);precondition(failedNew != nil)
  precondition(f.registrations==old && f.selections[name(d)] == nil && f.metadata[name(d)] == nil)
  print("PASS: failed new registration is removed without stopping preexisting rituals")

  f.failingAttempts=[];f.writeBeforeFailure=false
  f.registrations[name(b)]=nil
  let attempts=f.attempts
  let repaired=await schedule([a,b,c]);precondition(repaired == nil)
  precondition(f.registrations==old && f.attempts==attempts+1)
  print("PASS: missing system monitor is restored despite unchanged local fingerprint")

  let beforeCapacity=f.attempts;let beforeStops=f.stopped.count
  var sixA=a;var sixB=b;var sixC=c
  sixA.weekdays=Array(1...6);sixB.weekdays=Array(1...6);sixC.weekdays=Array(1...6)
  let overBudget=await schedule([sixA,sixB,sixC]);precondition(overBudget != nil)
  precondition(f.registrations==old && f.attempts==beforeCapacity && f.stopped.count==beforeStops)
  print("PASS: insufficient budget is rejected before any mutation, retaining auxiliary slots")

  f.failMetadataOnce=name(a)
  let badStorage=await schedule([changedA,b,c]);precondition(badStorage != nil)
  precondition(f.registrations==old && bytes(f.metadata)==oldMetadata)
  print("PASS: shared-state write failure retains previous schedules and metadata")

  // A safe final budget can still require too many transient staging slots.
  for i in 1...5 { f.registrations["aux.\(i)"]=old.values.first! }
  let withAux=f.registrations
  let replacements=(1...3).map { i -> RitualScheduler in
   var r=RitualScheduler(id:UUID(),title:"replacement \(i)",startHour:9,endHour:14)
   r.weekdays=Array(1...5);return r
  }
  let staging=await schedule(replacements);precondition(staging != nil)
  precondition(f.registrations==withAux)
  for i in 1...5 { f.registrations["aux.\(i)"]=nil }
  print("PASS: transient capacity check preserves the old plan and unrelated monitors")

  // If iOS also rejects rollback, report it explicitly instead of claiming success.
  f.failingAttempts=[f.attempts+1,f.attempts+2];f.writeBeforeFailure=true
  let recovery=await schedule([changedA,b,c])
  precondition(recovery?.localizedDescription.contains("recuperar toda") == true)
  precondition(defaults.string(forKey:"rituo.deviceActivity.scheduleFingerprint")==nil)
  precondition(f.registrations.count==3 && f.clears==0)
  print("PASS: rollback failure is surfaced and leaves fingerprint unconfirmed")

  f.failingAttempts=[];f.writeBeforeFailure=false
  let overnight=RitualScheduler(id:UUID(),title:"overnight",startHour:22,endHour:6)
  var weekly=RitualScheduler(id:UUID(),title:"selected days",startHour:23,endHour:7)
  weekly.weekdays=[2,4,6]
  let calendarPlan=await schedule([overnight,weekly]);precondition(calendarPlan == nil)
  precondition(f.registrations.count==4)
  let dailyNight=f.registrations[name(overnight)]!
  precondition(dailyNight.start.weekday == nil && dailyNight.end.weekday == nil)
  precondition(dailyNight.start.hour==22 && dailyNight.end.hour==6 && dailyNight.repeats)
  for day in weekly.weekdays {
   let entry=f.registrations[name(weekly,day)]!
   precondition(entry.start.weekday==day && entry.end.weekday==day%7+1)
  }
  print("PASS: overnight daily and selected-weekday schedules retain their calendar boundaries")
 }
}
'''
with tempfile.TemporaryDirectory(prefix='rituo-safety-tests-') as directory:
 d=Path(directory);(d/'Tests.swift').write_text(fixtures+metadata+source+tests)
 subprocess.run(['/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc','-sdk','/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk','-parse-as-library','-module-cache-path',str(d/'cache'),str(d/'Tests.swift'),'-o',str(d/'tests')],check=True)
 subprocess.run([str(d/'tests')],check=True)
