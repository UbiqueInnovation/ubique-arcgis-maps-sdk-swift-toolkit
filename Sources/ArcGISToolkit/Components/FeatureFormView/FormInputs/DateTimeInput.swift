// Copyright 2023 Esri
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import ArcGIS

/// A view for date/time input.
struct DateTimeInput: View {
    @Environment(\.formElementPadding) var elementPadding
    
    /// The view model for the form.
    @EnvironmentObject var model: FormViewModel
    
    // State properties for element events.
    
    @State private var isRequired: Bool = false
    @State private var isEditable: Bool = false
    @State private var formattedValue: String = ""
    
    /// The current date selection.
    @State private var date: Date?
    
    /// A Boolean value indicating whether a new date (or time is being set).
    @State private var isEditing = false
    
    /// The input's parent element.
    private let element: FieldFormElement
    
    /// The input configuration of the view.
    private let input: DateTimePickerFormInput
    
    /// Creates a view for a date (and time if applicable) input.
    /// - Parameters:
    ///   - element: The input's parent element.
    init(element: FieldFormElement) {
        precondition(
            element.input is DateTimePickerFormInput,
            "\(Self.self).\(#function) element's input must be \(DateTimePickerFormInput.self)."
        )
        
        self.element = element
        self.input = element.input as! DateTimePickerFormInput
    }
    
    var body: some View {
        Group {
            InputHeader(element: element)
                .padding([.top], elementPadding)
            
            dateEditor
            
            InputFooter(element: element)
        }
        .padding([.bottom], elementPadding)
        .onChange(of: model.focusedElement) { focusedElement in
            isEditing = focusedElement == element
        }
        .onChange(of: date) { date in
            element.updateValue(date)
            formattedValue = element.formattedValue
            model.evaluateExpressions()
        }
        .onChangeOfValue(of: element) { newValue, newFormattedValue in
            if newFormattedValue.isEmpty {
                date = nil
            } else {
                date = newValue as? Date
            }
            formattedValue = newFormattedValue
        }
        .onChangeOfIsRequired(of: element) { newIsRequired in
            isRequired = newIsRequired
        }
        .onChangeOfIsEditable(of: element) { newIsEditable in
            isEditable = newIsEditable
        }
    }
    
    /// Controls for modifying the date selection.
    @ViewBuilder var dateEditor: some View {
        dateDisplay
        if isEditing {
            datePicker
                .datePickerStyle(.graphical)
        }
    }
    
    /// Elements for display the date selection.
    /// - Note: Secondary foreground color is used across input views for consistency.
    @ViewBuilder var dateDisplay: some View {
        HStack {
            Text(!formattedValue.isEmpty ? formattedValue : .noValue)
                .accessibilityIdentifier("\(element.label) Value")
                .foregroundColor(displayColor)
            
            Spacer()
            
            if isEditing {
                todayOrNowButton
            } else if isEditable {
                if date == nil {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("\(element.label) Calendar Image")
                } else {
                    ClearButton {
                        model.focusedElement = element
                        defer { model.focusedElement = nil }
                        date = nil
                    }
                    .accessibilityIdentifier("\(element.label) Clear Button")
                }
            }
        }
        .formInputStyle()
        .frame(maxWidth: .infinity)
        .onTapGesture {
            withAnimation {
                guard isEditable else { return }
                if date == nil {
                    if dateRange.contains(.now) {
                        date = .now
                    } else if let min = input.min {
                        date = min
                    } else if let max = input.max {
                        date = max
                    }
                }
                isEditing.toggle()
                model.focusedElement = isEditing ? element : nil
            }
        }
    }
    
    /// Controls for making a specific date selection.
    @ViewBuilder var datePicker: some View {
        DatePicker(
            selection: Binding($date)!,
            in: dateRange,
            displayedComponents: input.includeTime ? [.date, .hourAndMinute] : [.date]
        ) { }
            .accessibilityIdentifier("\(element.label) Date Picker")
    }
    
    /// The range of dates available for selection, if applicable.
    var dateRange: ClosedRange<Date> {
        if let min = input.min, let max = input.max {
            return min...max
        } else if let min = input.min {
            return min...Date.distantFuture
        } else if let max = input.max {
            return Date.distantPast...max
        } else {
            return Date.distantPast...Date.distantFuture
        }
    }
    
    /// The color in which to display the selected date.
    var displayColor: Color {
        if date == nil {
            return .secondary
        } else if isEditing {
            return .accentColor
        } else {
            return .primary
        }
    }
    
    /// The button to set the date to the present time.
    var todayOrNowButton: some View {
        Button {
            let now = Date.now
            if dateRange.contains(now) {
                date = now
            } else if now > dateRange.upperBound {
                date = dateRange.upperBound
            } else {
                date = dateRange.lowerBound
            }
        } label: {
            input.includeTime ? Text.now : .today
        }
        .accessibilityIdentifier("\(element.label) \(input.includeTime ? "Now" : "Today") Button")
    }
}

private extension Text {
    /// A label for a button to choose the current time and date for a field.
    static var now: Self {
        .init(
            "Now",
            bundle: .toolkitModule,
            comment: "A label for a button to choose the current time and date for a field."
        )
    }
    
    /// A label for a button to choose the current date for a field.
    static var today: Self {
        .init(
            "Today",
            bundle: .toolkitModule,
            comment: "A label for a button to choose the current date for a field."
        )
    }
}
