import SwiftUI
import FamilyControls

@available(iOS 15.0, *)
struct ActivityPicker: View {
    @Binding var selection: FamilyActivitySelection
    var onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Select Apps to Block")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            onDismiss()
                        }
                    }
                }
        }
    }
}
