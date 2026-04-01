import SwiftUI

// MARK: - View Model

class TaskViewModel: ObservableObject {
    @Published var overdue: [TaskItem] = []
    @Published var dueToday: [TaskItem] = []
    @Published var pending: [TaskItem] = []
    @Published var done: [TaskItem] = []
    @Published var isLoading = false
    @Published var error: String?

    var isEmpty: Bool {
        overdue.isEmpty && dueToday.isEmpty && pending.isEmpty && done.isEmpty
    }

    var totalPending: Int { overdue.count + dueToday.count + pending.count }

    func refresh() {
        isLoading = true
        error = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let scanner = TaskScanner()
            let tasks = scanner.scan()

            let overdue = tasks.filter { !$0.isDone && $0.isOverdue }
                .sorted { ($0.due ?? "") < ($1.due ?? "") }
            let today = tasks.filter { !$0.isDone && $0.isDueToday }
                .sorted { ($0.due ?? "") < ($1.due ?? "") }
            let upcoming = tasks.filter { !$0.isDone && !$0.isOverdue && !$0.isDueToday }
                .sorted { ($0.due ?? "9999") < ($1.due ?? "9999") }
            let done = tasks.filter { $0.isDone }
                .sorted { ($0.due ?? "") > ($1.due ?? "") }

            DispatchQueue.main.async {
                self?.overdue = overdue
                self?.dueToday = today
                self?.pending = upcoming
                self?.done = Array(done.prefix(15))
                self?.isLoading = false
            }
        }
    }
}

// MARK: - Main View

struct TaskListView: View {
    @StateObject private var vm = TaskViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 340, height: 460)
        .onAppear { vm.refresh() }
    }

    private var header: some View {
        HStack {
            Image(systemName: "checklist")
                .foregroundStyle(.secondary)
            Text("Tasks")
                .font(.headline)
            Spacer()
            Button { vm.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            Spacer()
            ProgressView().controlSize(.small)
            Spacer()
        } else if vm.isEmpty {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("No tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    sections
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private var sections: some View {
        if !vm.overdue.isEmpty {
            SectionView(
                title: "Overdue", count: vm.overdue.count,
                color: .red, tasks: vm.overdue)
        }
        if !vm.dueToday.isEmpty {
            SectionView(
                title: "Due Today", count: vm.dueToday.count,
                color: .orange, tasks: vm.dueToday)
        }
        if !vm.pending.isEmpty {
            SectionView(
                title: "Upcoming", count: vm.pending.count,
                color: .blue, tasks: vm.pending)
        }
        if !vm.done.isEmpty {
            SectionView(
                title: "Done", count: vm.done.count,
                color: .green, tasks: vm.done, startCollapsed: true)
        }
    }

    private var footer: some View {
        HStack {
            Text("\(vm.totalPending) pending")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Section

struct SectionView: View {
    let title: String
    let count: Int
    let color: Color
    let tasks: [TaskItem]
    var startCollapsed: Bool = false

    @State private var expanded: Bool

    init(
        title: String, count: Int, color: Color,
        tasks: [TaskItem], startCollapsed: Bool = false
    ) {
        self.title = title
        self.count = count
        self.color = color
        self.tasks = tasks
        self.startCollapsed = startCollapsed
        _expanded = State(initialValue: !startCollapsed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 10)

                    Circle()
                        .fill(color.opacity(0.7))
                        .frame(width: 7, height: 7)

                    Text(title)
                        .font(.system(size: 11, weight: .semibold))

                    Text("\(count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 5)

            if expanded {
                ForEach(tasks) { task in
                    TaskRowView(task: task)
                }
            }
        }
    }
}

// MARK: - Task Row

struct TaskRowView: View {
    let task: TaskItem

    var body: some View {
        HStack(spacing: 8) {
            Text(task.statusSymbol)
                .font(.system(size: 11))
                .foregroundStyle(statusColor)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.description)
                    .font(.system(size: 12))
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .strikethrough(task.isDone)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let due = task.formattedDue {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                            Text(due)
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }
                    if let p = task.prioritySymbol {
                        Text(p)
                            .font(.system(size: 10))
                            .foregroundStyle(priorityColor)
                    }
                    ForEach(task.tags.filter { $0 != "task" }, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tint.opacity(0.7))
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .padding(.leading, 12)
    }

    private var statusColor: Color {
        switch task.status {
        case "/": return .blue
        case "x": return .green
        default: return .secondary
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case "highest", "high": return .red
        case "medium": return .orange
        default: return .blue
        }
    }
}
