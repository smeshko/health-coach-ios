import SwiftUI

/// iOS status chrome (time + signal/wifi/battery) pinned to the top of every screen. All glyphs `$fg`.
public struct StatusBar: View {
  public let time: String

  public init(time: String = "9:41") {
    self.time = time
  }

  public var body: some View {
    HStack {
      Text(time).font(.system(size: 17, weight: .semibold))
      Spacer()
      HStack(spacing: CoachSpacing.space6) {
        Image(systemName: Icon.cellular.systemName)
        Image(systemName: Icon.wifi.systemName)
        Image(systemName: Icon.battery.systemName)
      }
      .font(.system(size: 15))
    }
    .foregroundStyle(CoachColor.foreground)
    .padding(.horizontal, CoachSpacing.space16)
    .frame(height: ComponentMetrics.statusBarHeight)
  }
}
