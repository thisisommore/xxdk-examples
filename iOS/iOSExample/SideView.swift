import SwiftUI

extension UIScreen {
    static let screenWidth = UIScreen.main.bounds.size.width
    static let screenHeight = UIScreen.main.bounds.size.height
    static let screenSize = UIScreen.main.bounds.size
    
    // Width percentage function
    static func w(_ percentage: CGFloat) -> CGFloat {
        return screenWidth * (percentage / 100)
    }
    
    // Height percentage function
    static func h(_ percentage: CGFloat) -> CGFloat {
        return screenHeight * (percentage / 100)
    }
}
struct SideView: View {
    let minWidthLeft: CGFloat = UIScreen.w(40)
    let maxWidthLeft: CGFloat = UIScreen.w(60)
    @State var leftW: CGFloat = UIScreen.w(30)
    @State var rightW: CGFloat = UIScreen.w(70)
    var body: some View {
        HStack(alignment: .center) {
            HomeView<XXDK>(width: leftW)
            Resizer()
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            leftW = min(maxWidthLeft,max(minWidthLeft, leftW + value.translation.width))
                            rightW = UIScreen.w(100)-leftW
                        }
                )
            ChatView(width: rightW,chatId: "", chatTitle: "yo")
        }
        .onAppear {
            leftW = minWidthLeft
        }
    }
}

struct RedRectangle: View {
    let width: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.pink)
            .frame(width: width, height: 100)
    }
}


struct GreenRectangle: View {
    let width: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.green)
            .frame(width: width, height: 100)
    }
}

struct Resizer: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray)
            .frame(width: 8, height: 75)
            .cornerRadius(10)
    }
}

#Preview {
    SideView()
}
