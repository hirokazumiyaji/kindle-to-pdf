import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            NavigationSplitView {
                List(AppSection.allCases, selection: $model.selectedSection) { section in
                    Text(section.title)
                        .tag(section)
                }
            } detail: {
                switch model.selectedSection {
                case .scan:
                    ScanView(viewModel: model.scanViewModel)
                case .library:
                    LibraryView(viewModel: model.libraryViewModel)
                case .setup:
                    SetupView(viewModel: model.setupViewModel)
                case .settings:
                    SettingsView(viewModel: model.settingsViewModel)
                }
            }
            .disabled(model.showPermissionSheet)

            if model.showPermissionSheet {
                permissionOverlay
            }
        }
        .onAppear {
            model.presentPermissionsIfNeeded()
        }
    }

    /// 権限シートはAppKitのモーダルシートではなくオーバーレイで表示する。
    /// モーダルシートはウィンドウのcloseを拒否させるため、
    /// 「終了して再度開く」やCmd+Qが効かなくなる。オーバーレイなら終了を妨げない。
    private var permissionOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.2))
                .ignoresSafeArea()
            PermissionSetupSheet(
                status: model.permissionStatus,
                onDismiss: { model.showPermissionSheet = false }
            ) {
                model.refreshPermissionStatus()
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.35), radius: 24)
            )
            .padding(32)
        }
    }
}
