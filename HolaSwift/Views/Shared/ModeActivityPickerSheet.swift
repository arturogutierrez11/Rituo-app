import FamilyControls
import SwiftUI

struct ModeActivityPickerSheet: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    let mode: FocusMode
    @Environment(\.dismiss) private var dismiss
    @State private var draftSelection: FamilyActivitySelection
    @State private var isSaving = false

    init(viewModel: BlockSetupViewModel, mode: FocusMode) {
        self.viewModel = viewModel
        self.mode = mode
        _draftSelection = State(initialValue: mode.selection)
    }

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $draftSelection)
                .navigationTitle("Apps del modo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancelar") {
                            viewModel.cancelModeActivityPickerSelection()
                            dismiss()
                        }
                        .disabled(isSaving)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Guardar") {
                            isSaving = true
                            let didSave = viewModel.saveModeActivityPickerSelection(
                                for: mode.id,
                                selection: draftSelection
                            )
                            isSaving = false

                            if didSave {
                                dismiss()
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(isSaving)
                    }
                }
                .overlay {
                    if isSaving {
                        ZStack {
                            Color.black.opacity(0.18)
                                .ignoresSafeArea()

                            ProgressView("Guardando")
                                .padding(.horizontal, 22)
                                .padding(.vertical, 16)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .safeAreaInset(edge: .top) {
                    // iOS/Screen Time has an undocumented limit on how many
                    // apps it can actually shield when several categories are
                    // combined — the category token is opaque, so this is the
                    // closest signal the app can see.
                    if draftSelection.categoryTokens.count >= 2 {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text("Elegiste varias categorías juntas. Con muchas apps combinadas, iOS a veces no bloquea todas — probá el bloqueo antes de confiar en él, o elegí apps una por una si necesitás que sea seguro.")
                                .font(.footnote.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.85))
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if let message = viewModel.modeMessage, !message.isEmpty {
                        Text(message)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(RituoPalette.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(RituoPalette.deepOceanBlue)
                    }
                }
        }
        .interactiveDismissDisabled(isSaving)
    }
}
