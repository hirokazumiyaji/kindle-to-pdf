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
            Text(model.selectedSection.title)
        }
    }
}
