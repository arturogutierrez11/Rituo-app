import SwiftUI

struct LegalAcceptanceView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var hasAccepted = false
    @State private var selectedDocument: LegalDocumentResponse?

    private var documents: [LegalDocumentResponse] {
        authViewModel.legalRequirements?.documents ?? []
    }

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Image("RituoLogoWhite")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 174)
                        .padding(.top, 72)

                    VStack(spacing: 12) {
                        Text("Antes de continuar")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(RituoPalette.white)

                        Text("Necesitamos que leas y aceptes los documentos legales vigentes de Rituo.")
                            .font(.system(size: 15))
                            .foregroundStyle(RituoPalette.white.opacity(0.58))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                            Button {
                                selectedDocument = document
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: document.type == .terms ? "doc.text" : "lock.shield")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(RituoPalette.lightBlue)
                                        .frame(width: 38, height: 38)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(RituoPalette.lightBlue.opacity(0.10))
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(document.type.displayName)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(RituoPalette.white)

                                        Text("Versión \(document.version) · Leer documento")
                                            .font(.system(size: 12))
                                            .foregroundStyle(RituoPalette.white.opacity(0.38))
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(RituoPalette.white.opacity(0.25))
                                }
                                .padding(17)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < documents.count - 1 {
                                Rectangle()
                                    .fill(RituoPalette.white.opacity(0.06))
                                    .frame(height: 1)
                                    .padding(.leading, 68)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(red: 0.12, green: 0.16, blue: 0.26).opacity(0.94))
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(RituoPalette.white.opacity(0.07))
                            }
                    )

                    Button {
                        hasAccepted.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: hasAccepted ? "checkmark.square.fill" : "square")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(hasAccepted ? RituoPalette.lightBlue : RituoPalette.white.opacity(0.40))

                            Text(acceptanceText)
                                .font(.system(size: 14))
                                .foregroundStyle(RituoPalette.white.opacity(0.76))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)

                    if let error = authViewModel.legalRequirementsError {
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.62))
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await authViewModel.acceptLegalDocuments() }
                    } label: {
                        HStack(spacing: 9) {
                            if authViewModel.isAcceptingLegalDocuments {
                                ProgressView().tint(RituoPalette.deepOceanBlue)
                            }
                            Text(authViewModel.isAcceptingLegalDocuments ? "Guardando…" : "Aceptar y continuar")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(RituoPalette.deepOceanBlue)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(RituoPalette.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasAccepted || authViewModel.isAcceptingLegalDocuments)
                    .opacity(hasAccepted ? 1 : 0.42)

                    Button("Cerrar sesión") {
                        authViewModel.signOut()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RituoPalette.white.opacity(0.46))
                    .padding(.bottom, 34)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(item: $selectedDocument) { document in
            LegalDocumentDetailView(document: document)
        }
    }

    private var acceptanceText: String {
        let names = documents.map(\.type.displayName)
        if names.count == 1, let name = names.first {
            return "Leí y acepto \(name)."
        }
        return "Leí y acepto los documentos legales indicados."
    }
}

struct LegalRequirementsLoadingView: View {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            VStack(spacing: 24) {
                Image("RituoLogoWhite")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 154)

                if authViewModel.isLoadingLegalRequirements ||
                    authViewModel.legalRequirementsError == nil {
                    ProgressView()
                        .tint(RituoPalette.white)

                    Text("Verificando documentos vigentes…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RituoPalette.white.opacity(0.52))
                } else {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 34))
                        .foregroundStyle(RituoPalette.lightBlue)

                    Text(authViewModel.legalRequirementsError ?? "")
                        .font(.system(size: 15))
                        .foregroundStyle(RituoPalette.white.opacity(0.70))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Button("Volver a intentar") {
                        Task { await authViewModel.loadLegalRequirements() }
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(RituoPalette.deepOceanBlue)
                    .padding(.horizontal, 28)
                    .frame(minHeight: 52)
                    .background(RituoPalette.white)
                    .clipShape(Capsule())

                    Button("Cerrar sesión") {
                        authViewModel.signOut()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RituoPalette.white.opacity(0.46))
                }
            }
            .padding(28)
        }
    }
}

struct LegalDocumentDetailView: View {
    let document: LegalDocumentResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.10, blue: 0.18)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(document.title)
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(RituoPalette.white)

                        Text("Versión \(document.version)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RituoPalette.lightBlue)

                        Text(document.content)
                            .font(.system(size: 14))
                            .foregroundStyle(RituoPalette.white.opacity(0.68))
                            .lineSpacing(5)
                            .textSelection(.enabled)

                        if let rawURL = document.sourceUrl,
                           let url = URL(string: rawURL) {
                            Link("Abrir documento original", destination: url)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(RituoPalette.lightBlue)
                                .padding(.vertical, 12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(RituoPalette.white)
                }
            }
            .toolbarBackground(Color(red: 0.08, green: 0.10, blue: 0.18), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
