import Library
import SwiftUI

@available(iOS 14.0, *)
struct BackerDashboardTabBarView: View {
  @State var currentTab: BackerDashboardTab = .backed
  @State var backedTabText: String
  @State var savedTabText: String

  @Namespace var animation

  var selectTab: (BackerDashboardTab) -> ()

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 48) {
        ForEach(BackerDashboardTab.allCases, id: \.self) { type in
          TabView(type: type)
        }
      }
      .padding(.leading, 21)
    }
  }

  // MARK: @ViewBuilders

  @ViewBuilder
  func TabView(type: BackerDashboardTab) -> some View {
    Button {
      withAnimation {
        currentTab = type
        selectTab(currentTab)
      }
    } label: {
      Group {
        VStack(alignment: .leading, spacing: 2) {
          Text(type == .backed ? backedTabText : savedTabText)
            .font(.system(size: 13))
            .fontWeight(.semibold)
            .multilineTextAlignment(.leading)
            .foregroundColor(currentTab == type ? .black : .gray)
            .foregroundColor(.gray)
            .padding(.bottom, 15)
            .overlay(
              ZStack {
                if currentTab == type {
                  Capsule()
                    .fill(.black)
                    .matchedGeometryEffect(id: "TABBARANIMATION", in: animation)
                    .frame(height: 2)
                } else {
                  Capsule()
                    .fill(.clear)
                    .frame(height: 2)
                }
              },
              alignment: .bottom
            )
        }
      }
      .padding(0)
    }
  }
}

@available(iOS 14.0, *)
struct BackerDashboardTabBar_Previews: PreviewProvider {
  static var previews: some View {
    return BackerDashboardTabBarView(
      backedTabText: "0\nbacked",
      savedTabText: "0\nsaved",
      selectTab: { _ in }
    )
    .previewLayout(.sizeThatFits)
  }
}
