import AuthenticationServices
import FamilyControls
import ManagedSettings
import SwiftUI

struct FocusSetupPage: View {
    @ObservedObject var viewModel: BlockSetupViewModel

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    BrandScreenHeader(
                        eyebrow: "Focus",
                        quote: "Prepará el entorno antes de pedirle foco a tu mente."
                    )

                    BrandPanel {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Configuración")
                                .font(.custom("Helvetica", size: 24).weight(.bold))
                                .foregroundStyle(RituoPalette.white)

                            SystemStatusRow(title: "Screen Time", value: viewModel.authorizationStatusText, isOn: viewModel.isAuthorized)
                            SystemStatusRow(title: "Selección", value: viewModel.selectionSummary, isOn: viewModel.selectedItemCount > 0)
                            SystemStatusRow(title: "Tag NFC", value: viewModel.registeredTagIdentifier == nil ? "Sin vincular" : "Vinculado", isOn: viewModel.registeredTagIdentifier != nil)
                        }
                    }

                    BrandPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Diagnóstico scheduler")
                                    .font(.custom("Helvetica", size: 18).weight(.bold))
                                    .foregroundStyle(RituoPalette.white)

                                Spacer()

                                Button {
                                    viewModel.clearDeviceActivityDebugEvents()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(RituoPalette.white.opacity(0.72))
                                }
                                .buttonStyle(.plain)
                            }

                            if viewModel.deviceActivityDebugEvents.isEmpty {
                                Text("Sin eventos todavía.")
                                    .font(.custom("Helvetica", size: 13).weight(.medium))
                                    .foregroundStyle(RituoPalette.white.opacity(0.64))
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("\(viewModel.deviceActivityDebugEvents.count) eventos recientes")
                                        .font(.custom("Helvetica", size: 13).weight(.bold))
                                        .foregroundStyle(RituoPalette.mistBlue.opacity(0.80))

                                    ForEach(Array(viewModel.deviceActivityDebugEvents.prefix(4)), id: \.self) { event in
                                        HStack(alignment: .top, spacing: 8) {
                                            Circle()
                                                .fill(RituoPalette.mistBlue.opacity(0.62))
                                                .frame(width: 6, height: 6)
                                                .padding(.top, 5)

                                            Text(event)
                                                .font(.custom("Helvetica", size: 10).weight(.medium))
                                                .foregroundStyle(RituoPalette.white.opacity(0.62))
                                                .lineLimit(2)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        Button {
                            Task { await viewModel.requestAuthorization() }
                        } label: {
                            Label(viewModel.isAuthorized ? "Screen Time autorizado" : "Autorizar Screen Time", systemImage: "shield")
                                .font(.custom("Helvetica", size: 16).weight(.bold))
                                .foregroundStyle(RituoPalette.deepOceanBlue)
                                .frame(maxWidth: .infinity, minHeight: 58)
                                .background(RituoPalette.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(LoginPressButtonStyle())
                        .disabled(viewModel.isAuthorizing)

                        Button {
                            Task {
                                await viewModel.openActivityPicker()
                            }
                        } label: {
                            Label("Seleccionar aplicaciones", systemImage: "square.grid.2x2")
                                .font(.custom("Helvetica", size: 16).weight(.bold))
                                .foregroundStyle(RituoPalette.lightBlue)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(HomeDarkCardBackground(cornerRadius: 16))
                        }
                        .buttonStyle(LoginPressButtonStyle())

                        Button {
                            if viewModel.registeredTagIdentifier == nil {
                                viewModel.registerTag()
                            } else if viewModel.isBlocking {
                                viewModel.endBlockWithTag()
                            } else {
                                viewModel.startBlockWithTag()
                            }
                        } label: {
                            Label(viewModel.registeredTagIdentifier == nil ? "Registrar tag NFC" : "Usar tag NFC", systemImage: "tag")
                                .font(.custom("Helvetica", size: 16).weight(.bold))
                                .foregroundStyle(RituoPalette.lightBlue)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(HomeDarkCardBackground(cornerRadius: 16))
                        }
                        .buttonStyle(LoginPressButtonStyle())
                    }

                    BrandPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Duración rápida")
                                .font(.custom("Helvetica", size: 20).weight(.bold))
                                .foregroundStyle(RituoPalette.white)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(BlockDuration.allCases) { duration in
                                    Button {
                                        viewModel.selectedDuration = duration
                                    } label: {
                                        Text(duration.title)
                                            .font(.custom("Helvetica", size: 15).weight(.bold))
                                            .foregroundStyle(viewModel.selectedDuration == duration ? RituoPalette.deepOceanBlue : RituoPalette.white)
                                            .frame(maxWidth: .infinity, minHeight: 46)
                                            .background(viewModel.selectedDuration == duration ? RituoPalette.white : Color.black.opacity(0.18))
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 76)
                .padding(.bottom, 20)
            }
        }
    }
}
