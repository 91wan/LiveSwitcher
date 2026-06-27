import SwiftUI

extension StudioTheme {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    static let spacingXS = Spacing.xxs
    static let spacingS = Spacing.xs
    static let spacingM = Spacing.s
    static let spacingL = Spacing.l
    static let spacingXL = Spacing.xl

    static let radiusS = Radius.s
    static let radiusM = Radius.m
    static let radiusL = Radius.l
    static let radiusXL = Radius.xl

    static let controlHeightS: CGFloat = 30
    static let controlHeightM: CGFloat = 38
    static let controlHeightL: CGFloat = 46

    static let directorRailWidth: CGFloat = 320
    static let monitorRadius: CGFloat = 24
}
