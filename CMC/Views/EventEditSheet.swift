import SwiftUI
#if os(iOS)
import EventKit
import EventKitUI
#endif

/// Adds a calendar entry to the user's own calendar.
///
/// Always via `EKEventEditViewController`, so the user reviews and confirms —
/// the app never writes to a calendar silently (PLAN §5.3). On macOS, which has
/// no `EventKitUI`, the event is offered as a one-event `.ics` instead; the
/// user still does the adding.
struct EventEditSheet: View {
    let event: CalendarEvent

    var body: some View {
        #if os(iOS)
        EventEditController(event: event).ignoresSafeArea()
        #else
        SingleEventExportSheet(event: event)
        #endif
    }
}

#if os(iOS)
private struct EventEditController: UIViewControllerRepresentable {
    let event: CalendarEvent

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.editViewDelegate = context.coordinator
        controller.event = makeEvent(in: store)
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    private func makeEvent(in store: EKEventStore) -> EKEvent {
        let calendarEvent = EKEvent(eventStore: store)
        calendarEvent.title = event.titles.joined(separator: " · ")
        calendarEvent.notes = "Calendário do Colégio Marista de Carcavelos — \(event.rawDate)"
        calendarEvent.isAllDay = true
        calendarEvent.calendar = store.defaultCalendarForNewEvents

        // Only exportable expressions reach here; guard anyway rather than
        // inventing a date.
        let start = event.sortDate ?? Date()
        calendarEvent.startDate = start
        calendarEvent.endDate = event.lastDate ?? start
        return calendarEvent
    }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        private let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func eventEditViewController(
            _ controller: EKEventEditViewController,
            didCompleteWith action: EKEventEditViewAction
        ) {
            dismiss()
        }
    }
}
#else
private struct SingleEventExportSheet: View {
    let event: CalendarEvent

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Evento", value: event.titles.joined(separator: " · "))
                    LabeledContent("Data", value: event.rawDate)
                }
                if let result = try? ICSExport.write(event: event) {
                    Section {
                        ShareLink(item: result.fileURL) {
                            Label("Adicionar ao Calendário (.ics)", systemImage: "calendar.badge.plus")
                        }
                    }
                }
            }
            .navigationTitle("Adicionar evento")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        .mediumSheet()
    }
}
#endif

/// Confirmation for the year-long `.ics` export, which says out loud how many
/// entries it could not include.
struct ICSExportSheet: View {
    let result: ICSExport.Result

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Eventos exportados", value: "\(result.exportedCount)")
                    if result.skippedCount > 0 {
                        LabeledContent("Não exportados", value: "\(result.skippedCount)")
                    }
                } footer: {
                    if result.skippedCount > 0 {
                        Text("Eventos com datas ambíguas (por exemplo «8 ou 22 de maio») ou em formato não reconhecido não são exportados, para não escolhermos uma data por si.")
                    }
                }

                Section {
                    ShareLink(item: result.fileURL) {
                        Label("Partilhar ficheiro .ics", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Exportar calendário")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        .mediumSheet()
    }
}
