//
//  JITALiveActivity.swift
//  JITALiveActivity
//
//  iOS Live Activity widget for JITA — displays "Leave By" time
//  and current route duration on the lock screen and Dynamic Island.
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Activity Attributes

/// Must be named exactly `LiveActivitiesAppAttributes` for the
/// `live_activities` Flutter package to recognize it.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {}

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}

// MARK: - Shared UserDefaults

/// Shared container so Flutter can write data that the widget reads.
let sharedDefault = UserDefaults(suiteName: "group.com.jita.jita")!

// MARK: - Widget Bundle

@main
struct JITAWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            JITALiveActivityWidget()
        }
    }
}

// MARK: - Live Activity Widget

@available(iOSApplicationExtension 16.1, *)
struct JITALiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // Lock screen / banner Live Activity view
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenter(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOSApplicationExtension 16.1, *)
struct LockScreenView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>

    var body: some View {
        let leaveByTime = sharedDefault.string(
            forKey: context.attributes.prefixedKey("leaveByTime")) ?? "--:--"
        let durationMinutes = sharedDefault.integer(
            forKey: context.attributes.prefixedKey("currentDurationMinutes"))
        let destinationName = sharedDefault.string(
            forKey: context.attributes.prefixedKey("destinationName")) ?? "Destination"
        let isLate = sharedDefault.bool(
            forKey: context.attributes.prefixedKey("isLate"))

        HStack(spacing: 16) {
            // Leave By section
            VStack(alignment: .center, spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundColor(isLate ? .red : .blue)
                Text("Leave By")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(leaveByTime)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(isLate ? .red : .primary)
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1, height: 50)

            // Duration section
            VStack(alignment: .center, spacing: 4) {
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Travel Time")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(durationMinutes) min")
                    .font(.title)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        // Destination label at the bottom
        .overlay(alignment: .bottom) {
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
                Text(destinationName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.bottom, 2)
        }
    }
}

// MARK: - Dynamic Island Expanded Views

@available(iOSApplicationExtension 16.1, *)
struct ExpandedLeading: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>

    var body: some View {
        let durationMinutes = sharedDefault.integer(
            forKey: context.attributes.prefixedKey("currentDurationMinutes"))
        VStack(alignment: .center, spacing: 2) {
            Image(systemName: "car.fill")
                .font(.title3)
                .foregroundColor(.orange)
            Text("\(durationMinutes) min")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text("Travel")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
struct ExpandedTrailing: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>

    var body: some View {
        let leaveByTime = sharedDefault.string(
            forKey: context.attributes.prefixedKey("leaveByTime")) ?? "--:--"
        let isLate = sharedDefault.bool(
            forKey: context.attributes.prefixedKey("isLate"))
        VStack(alignment: .center, spacing: 2) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3)
                .foregroundColor(isLate ? .red : .blue)
            Text(leaveByTime)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isLate ? .red : .white)
            Text("Leave By")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
struct ExpandedCenter: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>

    var body: some View {
        let destinationName = sharedDefault.string(
            forKey: context.attributes.prefixedKey("destinationName")) ?? "Destination"

        HStack(spacing: 4) {
            Image(systemName: "mappin.circle.fill")
                .font(.caption)
                .foregroundColor(.red)
            Text(destinationName)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Compact & Minimal Views

@available(iOSApplicationExtension 16.1, *)
struct CompactLeadingView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>

    var body: some View {
        let durationMinutes = sharedDefault.integer(
            forKey: context.attributes.prefixedKey("currentDurationMinutes"))
        HStack(spacing: 2) {
            Image(systemName: "car.fill")
                .foregroundColor(.orange)
            Text("\(durationMinutes)m")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
struct CompactTrailingView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>

    var body: some View {
        let leaveByTime = sharedDefault.string(
            forKey: context.attributes.prefixedKey("leaveByTime")) ?? "--:--"
        let isLate = sharedDefault.bool(
            forKey: context.attributes.prefixedKey("isLate"))
        HStack(spacing: 2) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(isLate ? .red : .blue)
            Text(leaveByTime)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isLate ? .red : .white)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
struct MinimalView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>

    var body: some View {
        let isLate = sharedDefault.bool(
            forKey: context.attributes.prefixedKey("isLate"))
        let durationMinutes = sharedDefault.integer(
            forKey: context.attributes.prefixedKey("currentDurationMinutes"))
        if durationMinutes > 0 {
            Text("\(durationMinutes)m")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isLate ? .red : .white)
        } else {
            Image(systemName: isLate ? "exclamationmark.circle.fill" : "car.fill")
                .foregroundColor(isLate ? .red : .blue)
        }
    }
}
