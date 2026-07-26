import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("SharedDrawing")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Canvas placeholder
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .background(Color.white)
                .overlay(
                    Text("Canvas Area")
                        .foregroundColor(.gray)
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 300)
                .padding()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
