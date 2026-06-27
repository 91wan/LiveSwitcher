import SwiftUI

struct BGMCategoryPicker: View {
    let selectedCategory: Binding<BGMCategory>

    var body: some View {
        HStack {
            Text("当前分类")
                .font(StudioTheme.TypeScale.caption.weight(.black))
                .foregroundStyle(StudioTheme.textSecondary)
            Spacer()
            Picker("", selection: selectedCategory) {
                ForEach(BGMCategory.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .font(StudioTheme.TypeScale.heading)
            .accessibilityLabel("BGM 分类")
            .accessibilityValue(selectedCategory.wrappedValue.rawValue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                .fill(StudioTheme.Surface.raised)
        )
    }
}
