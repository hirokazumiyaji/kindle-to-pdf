import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
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
        .sheet(isPresented: $model.showPermissionSheet) {
            PermissionSetupSheet(status: model.permissionStatus) {
                model.refreshPermissionStatus()
                if !model.needsPermissionSetup {
                    model.showPermissionSheet = false
                }
            }
        }
        .onAppear {
            model.presentPermissionsIfNeeded()
        }
        .onChange(of: model.selectedSection) { section in
            if section == .scan {
                model.presentPermissionsIfNeeded()
            }
        }
    }
}
