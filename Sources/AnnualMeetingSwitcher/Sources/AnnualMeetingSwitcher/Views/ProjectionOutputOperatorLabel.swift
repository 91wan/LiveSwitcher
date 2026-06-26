import SwiftUI

struct ProjectionOutputOperatorLabel: View {
    let model: ProjectionButtonModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(model.title)
                .font(StudioTheme.TypeScale.body.weight(.black))
            Text(model.screenLabel)
                .font(StudioTheme.TypeScale.caption.weight(.semibold))
                .opacity(0.86)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }
}
