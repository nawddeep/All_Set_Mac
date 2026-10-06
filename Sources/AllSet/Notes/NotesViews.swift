import AllSetCore
import AppKit
import SwiftUI

/// The island's Notes tab: short points, added from the field at the top.
struct NotesTab: View {
    let notes: NotesStore
    let model: NotchViewModel
    let openNotes: () -> Void

    @State private var draft = ""
    @FocusState private var isTyping: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(isTyping ? 0.9 : 0.5))
                TextField("", text: $draft, prompt: Text("Add a point, then press Return").foregroundStyle(.white.opacity(0.4)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .focused($isTyping)
                    .onSubmit {
                        withMotion(Motion.quick) { notes.add(draft) }
                        draft = ""
                    }
                    .onExitCommand {
                        draft = ""
                        isTyping = false
                    }
                Spacer(minLength: 4)
                if let removal = notes.lastRemoval {
                    Button("Undo") {
                        withMotion(Motion.quick) { notes.undoRemoval() }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .help(removal.count == 1 ? "Bring back the removed note" : "Bring back the \(removal.count) removed notes")
                }
                if notes.doneCount > 0 {
                    Button("Clear \(notes.doneCount) done") {
                        withMotion(Motion.quick) { notes.removeDone() }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .help("Remove the ticked notes (Undo brings them back)")
                }
                Button(action: openNotes) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .semibold))
                }
                .help("Open Notes in All Set")
            }
            .buttonStyle(NotchIconButtonStyle())
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(.white.opacity(isTyping ? 0.12 : 0.07)))

            if notes.notes.isEmpty {
                Text("Nothing noted yet. Click above and type.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(notes.notes) { note in
                            NoteRow(note: note, notes: notes, dark: true)
                        }
                    }
                }
            }
        }
        // Stays open while typing, even if the pointer wanders off.
        .onChange(of: isTyping) { model.isEditing = isTyping }
        .onDisappear { model.isEditing = false }
    }
}

/// A point: tick it off, change it (click the text, the pencil, or Edit in its
/// menu), or remove it. Every action is in the context menu and VoiceOver's
/// actions too, not only on hover.
struct NoteRow: View {
    let note: QuickNote
    let notes: NotesStore
    /// On the island's black background.
    var dark = false

    @State private var isHovering = false
    @State private var isEditing = false
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Button {
                withMotion(Motion.quick) { notes.toggle(note.id) }
            } label: {
                Image(systemName: note.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: dark ? 13 : 15))
                    .foregroundStyle(note.isDone ? Theme.charging : (dark ? Color.white.opacity(0.5) : Color.secondary))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help(note.isDone ? "Not done" : "Done")

            if isEditing {
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit(finishEditing)
                    .onExitCommand { isEditing = false }
                    .onChange(of: isFocused) { if !isFocused { finishEditing() } }
            } else {
                Text(note.text)
                    .strikethrough(note.isDone)
                    .foregroundStyle(note.isDone ? .secondary : .primary)
                    .lineLimit(dark ? 2 : nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: startEditing)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Edits the note")
                    .accessibilityAction(named: "Edit", startEditing)
                    .accessibilityAction(named: "Remove") { notes.remove(note.id) }
            }

            if isHovering, !isEditing {
                Button(action: startEditing) {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit")
                .accessibilityLabel("Edit note")
                Button {
                    withMotion(Motion.quick) { notes.remove(note.id) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove (Undo brings it back)")
                .accessibilityLabel("Remove note")
            }
        }
        .font(.system(size: dark ? 12 : 13, weight: dark ? .medium : .regular))
        .padding(.horizontal, 8)
        .padding(.vertical, dark ? 4 : 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(isHovering ? 0.07 : 0)))
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(note.text, forType: .string)
            }
            Button("Edit", action: startEditing)
            Button(note.isDone ? "Mark Not Done" : "Mark Done") { notes.toggle(note.id) }
            Divider()
            Button("Remove", role: .destructive) { notes.remove(note.id) }
        }
    }

    private func startEditing() {
        text = note.text
        isEditing = true
        isFocused = true
    }

    private func finishEditing() {
        guard isEditing else { return }
        isEditing = false
        notes.update(note.id, text: text)
    }
}

/// Notes in the main window: the same points, with room to see them all.
struct NotesPage: View {
    let notes: NotesStore

    @State private var draft = ""

    var body: some View {
        let open = notes.notes.filter { !$0.isDone }.count
        let done = notes.notes.filter(\.isDone).count
        VStack(alignment: .leading, spacing: DS.Space.m) {
            PageHeader(eyebrow: notes.notes.isEmpty ? "Tools" : "\(open) to do · \(done) done", title: "Notes",
                       subtitle: "Quick points, here or in the island\u{2019}s Notes tab. Pasting a list adds each line.") {
                HStack(spacing: DS.Space.xs) {
                    Button("Copy All") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(notes.asText, forType: .string)
                    }
                    .buttonStyle(.pill)
                    .disabled(notes.notes.isEmpty)
                    Button(done > 0 ? "Clear \(done) Done" : "Clear Done") { withMotion(Motion.standard) { notes.removeDone() } }
                        .buttonStyle(.pill)
                        .disabled(done == 0)
                        .help("Remove the ticked notes (Undo brings them back)")
                }
            }
            if let removal = notes.lastRemoval {
                HStack(spacing: DS.Space.s) {
                    Label(removal.count == 1 ? "Removed \u{201C}\(removal.notes[0].note.text)\u{201D}" : "Removed \(removal.count) notes",
                          systemImage: "trash")
                        .dsText(.body)
                        .lineLimit(1)
                    Spacer()
                    Button("Undo") { withMotion(Motion.standard) { notes.undoRemoval() } }
                        .buttonStyle(.pill)
                    Button {
                        notes.forgetRemoval()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                    .accessibilityLabel("Dismiss")
                }
            }
            if let error = notes.saveError {
                Label("Your notes couldn't be saved: \(error). They're still here; they'll be saved with the next change.",
                      systemImage: "exclamationmark.triangle.fill")
                    .dsText(.body)
                    .foregroundStyle(.orange)
            }

            HStack(spacing: DS.Space.s) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.92)))
                TextField("Add a point, then press Return", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .onSubmit {
                        withMotion(Motion.quick) { notes.add(draft) }
                        draft = ""
                    }
            }
            .padding(.horizontal, DS.Space.s)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Surface.raised))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).strokeBorder(DS.Surface.hairline))

            if notes.notes.isEmpty {
                EmptyState(symbol: "note.text", title: "No notes yet",
                           message: "Type above and press Return. Check points off as you go.")
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                List {
                    ForEach(notes.notes) { note in
                        NoteRow(note: note, notes: notes)
                            .listRowSeparator(.hidden)
                    }
                    .onMove { notes.move(from: $0, to: $1) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.top, DS.Space.l)
        .frame(maxWidth: 820, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
