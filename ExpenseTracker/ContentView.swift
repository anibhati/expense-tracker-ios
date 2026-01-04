//
//  Models.swift
//  Example
//

import Foundation

struct Expense: Identifiable, Codable, Hashable {
    var id = UUID()
    var amount: Double
    var category: ExpenseCategory
    var date: Date
    var description: String
    var notes: String?
    
    var formattedAmount: String {
        String(format: "$%.2f", amount)
    }
}

enum ExpenseCategory: String, Codable, CaseIterable {
    case food = "Food"
    case transportation = "Transportation"
    case shopping = "Shopping"
    case entertainment = "Entertainment"
    case bills = "Bills"
    case healthcare = "Healthcare"
    case education = "Education"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transportation: return "car.fill"
        case .shopping: return "cart.fill"
        case .entertainment: return "tv.fill"
        case .bills: return "doc.text.fill"
        case .healthcare: return "cross.case.fill"
        case .education: return "book.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

//
//  ExpenseStore.swift
//  Example
//

import Foundation
import Combine

class ExpenseStore: ObservableObject {
    @Published var expenses: [Expense] = []
    
    private let storageKey = "SavedExpenses"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {
        loadExpenses()
    }
    
    // MARK: - Computed Properties
    
    var totalExpenses: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    func totalForCategory(_ category: ExpenseCategory) -> Double {
        expenses.filter { $0.category == category }
            .reduce(0) { $0 + $1.amount }
    }
    
    func expensesForMonth(_ date: Date) -> [Expense] {
        let calendar = Calendar.current
        return expenses.filter { expense in
            calendar.isDate(expense.date, equalTo: date, toGranularity: .month)
        }
    }
    
    // MARK: - CRUD Operations
    
    func addExpense(_ expense: Expense) {
        expenses.append(expense)
        expenses.sort { $0.date > $1.date }
        saveExpenses()
    }
    
    func updateExpense(_ expense: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
            expenses.sort { $0.date > $1.date }
            saveExpenses()
        }
    }
    
    func deleteExpense(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        saveExpenses()
    }
    
    func deleteExpenses(at offsets: IndexSet) {
        expenses.remove(atOffsets: offsets)
        saveExpenses()
    }
    
    // MARK: - Persistence
    
    private func saveExpenses() {
        do {
            let data = try encoder.encode(expenses)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save expenses: \(error.localizedDescription)")
        }
    }
    
    private func loadExpenses() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }
        
        do {
            expenses = try decoder.decode([Expense].self, from: data)
            expenses.sort { $0.date > $1.date }
        } catch {
            print("Failed to load expenses: \(error.localizedDescription)")
            expenses = []
        }
    }
}

//
//  ContentView.swift
//  Example
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = ExpenseStore()
    @State private var showingAddExpense = false
    @State private var selectedExpense: Expense?
    @State private var showingDeleteAlert = false
    @State private var expenseToDelete: Expense?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Summary Card
                SummaryCard(total: store.totalExpenses)
                    .padding()
                
                // Expense List
                if store.expenses.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(groupedExpenses.keys.sorted(by: >), id: \.self) { date in
                            Section(header: Text(formatSectionDate(date))) {
                                ForEach(groupedExpenses[date] ?? []) { expense in
                                    ExpenseRow(expense: expense)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedExpense = expense
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                expenseToDelete = expense
                                                showingDeleteAlert = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            
                                            Button {
                                                selectedExpense = expense
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .tint(.blue)
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddExpense = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddEditExpenseView(store: store)
            }
            .sheet(item: $selectedExpense) { expense in
                AddEditExpenseView(store: store, expenseToEdit: expense)
            }
            .alert("Delete Expense?", isPresented: $showingDeleteAlert, presenting: expenseToDelete) { expense in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    store.deleteExpense(expense)
                }
            } message: { expense in
                Text("Are you sure you want to delete '\(expense.description)'?")
            }
        }
        .environmentObject(store)
    }
    
    // Group expenses by date
    private var groupedExpenses: [Date: [Expense]] {
        Dictionary(grouping: store.expenses) { expense in
            Calendar.current.startOfDay(for: expense.date)
        }
    }
    
    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

struct SummaryCard: View {
    let total: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Total Expenses")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(String(format: "$%.2f", total))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("No Expenses Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tap the + button to add your first expense")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct ExpenseRow: View {
    let expense: Expense
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.description)
                    .font(.headline)
                Text(expense.category.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(expense.formattedAmount)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 8)
    }
}

struct AddEditExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: ExpenseStore
    
    let expenseToEdit: Expense?
    
    @State private var amount: String
    @State private var description: String
    @State private var category: ExpenseCategory
    @State private var date: Date
    @State private var notes: String
    @State private var showingValidationError = false
    
    init(store: ExpenseStore, expenseToEdit: Expense? = nil) {
        self.store = store
        self.expenseToEdit = expenseToEdit
        
        _amount = State(initialValue: expenseToEdit.map { String(format: "%.2f", $0.amount) } ?? "")
        _description = State(initialValue: expenseToEdit?.description ?? "")
        _category = State(initialValue: expenseToEdit?.category ?? .food)
        _date = State(initialValue: expenseToEdit?.date ?? Date())
        _notes = State(initialValue: expenseToEdit?.notes ?? "")
    }
    
    var isEditing: Bool {
        expenseToEdit != nil
    }
    
    var isValid: Bool {
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        !amount.isEmpty &&
        Double(amount) != nil &&
        (Double(amount) ?? 0) > 0
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Description", text: $description)
                        .textInputAutocapitalization(.sentences)
                    
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                }
                
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle(isEditing ? "Edit Expense" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Update" : "Save") {
                        saveExpense()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .alert("Invalid Input", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a valid amount and description.")
            }
        }
    }
    
    private func saveExpense() {
        guard isValid,
              let amountValue = Double(amount),
              amountValue > 0 else {
            showingValidationError = true
            return
        }
        
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        
        if let existingExpense = expenseToEdit {
            let updatedExpense = Expense(
                id: existingExpense.id,
                amount: amountValue,
                category: category,
                date: date,
                description: trimmedDescription,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            store.updateExpense(updatedExpense)
        } else {
            let newExpense = Expense(
                amount: amountValue,
                category: category,
                date: date,
                description: trimmedDescription,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            store.addExpense(newExpense)
        }
        
        dismiss()
    }
}

#Preview {
    ContentView()
}
