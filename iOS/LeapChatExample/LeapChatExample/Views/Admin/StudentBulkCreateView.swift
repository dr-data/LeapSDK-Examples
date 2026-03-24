import SwiftUI
import SwiftData

struct StudentBulkCreateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let classroomId: String
    let teacherAccountId: UUID

    @State private var selectedYear = Calendar.current.component(.year, from: Date()) % 100
    @State private var formNumber = 1
    @State private var studentNumberFrom = 1
    @State private var studentNumberTo = 40
    @State private var createdStudents: [CreatedStudent] = []
    @State private var didCreate = false

    private let bgColor = Color(red: 0.067, green: 0.09, blue: 0.137)
    private let cardBg = Color(red: 0.098, green: 0.125, blue: 0.184)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)

    struct CreatedStudent: Identifiable {
        let id = UUID()
        let classcode: String
        let displayName: String
        let password: String
    }

    private var previewClasscodes: [String] {
        guard studentNumberFrom <= studentNumberTo else { return [] }
        let yearStr = String(format: "%02d", selectedYear)
        let formStr = "f\(formNumber)"
        return (studentNumberFrom...studentNumberTo).map { num in
            "\(yearStr)\(formStr)\(String(format: "%02d", num))"
        }
    }

    private var credentialsText: String {
        let header = "Classcode\tPassword\n"
        let rows = createdStudents.map { "\($0.classcode)\t\($0.password)" }
        return header + rows.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if didCreate {
                        createdView
                    } else {
                        createForm
                    }
                }
                .padding()
            }
            .background(bgColor.ignoresSafeArea())
            .navigationTitle("Bulk Create Students")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Create Form

    private var createForm: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Configuration")
                    .font(.headline)
                    .foregroundColor(.white)

                VStack(spacing: 16) {
                    Stepper(value: $selectedYear, in: 24...30) {
                        HStack {
                            Text("Year")
                                .foregroundColor(.white)
                            Spacer()
                            Text("20\(selectedYear)")
                                .foregroundColor(secondaryText)
                                .monospacedDigit()
                        }
                    }

                    Divider().overlay(Color(red: 0.2, green: 0.23, blue: 0.3))

                    Stepper(value: $formNumber, in: 1...6) {
                        HStack {
                            Text("Form / Class")
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(formNumber)")
                                .foregroundColor(secondaryText)
                                .monospacedDigit()
                        }
                    }

                    Divider().overlay(Color(red: 0.2, green: 0.23, blue: 0.3))

                    HStack {
                        Text("Student Numbers")
                            .foregroundColor(.white)
                        Spacer()
                        HStack(spacing: 8) {
                            TextField("From", value: $studentNumberFrom, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                            Text("to")
                                .foregroundColor(secondaryText)
                            TextField("To", value: $studentNumberTo, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                        }
                    }
                }
                .padding()
                .background(cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Preview
            VStack(alignment: .leading, spacing: 12) {
                Text("Preview (\(previewClasscodes.count) students)")
                    .font(.headline)
                    .foregroundColor(.white)

                if previewClasscodes.isEmpty {
                    Text("Invalid range")
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(previewClasscodes.prefix(5), id: \.self) { code in
                            Text(code)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        if previewClasscodes.count > 5 {
                            Text("... and \(previewClasscodes.count - 5) more")
                                .font(.caption)
                                .foregroundColor(secondaryText)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Button {
                createStudents()
            } label: {
                Text("Create \(previewClasscodes.count) Accounts")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(previewClasscodes.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(previewClasscodes.isEmpty)
        }
    }

    // MARK: - Created View

    private var createdView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("\(createdStudents.count) Students Created")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            VStack(spacing: 0) {
                HStack {
                    Text("Classcode")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Password")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider().overlay(Color(red: 0.2, green: 0.23, blue: 0.3))

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(createdStudents) { student in
                            HStack {
                                Text(student.classcode)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(student.password)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = credentialsText
                } label: {
                    Label("Copy All", systemImage: "doc.on.doc")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                ShareLink(item: credentialsText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue.opacity(0.3))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Button("Done") { dismiss() }
                .foregroundColor(secondaryText)
        }
    }

    // MARK: - Create

    private func createStudents() {
        var created: [CreatedStudent] = []
        let yearStr = String(format: "%02d", selectedYear)
        let formStr = "f\(formNumber)"

        for num in studentNumberFrom...studentNumberTo {
            let classcode = "\(yearStr)\(formStr)\(String(format: "%02d", num))"
            let password = String((0..<6).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
            let displayName = "Student \(classcode)"

            let account = UserAccount(
                classcode: classcode,
                displayName: displayName,
                role: .student,
                passwordHash: password,
                classroomId: classroomId,
                createdBy: teacherAccountId
            )
            modelContext.insert(account)
            created.append(CreatedStudent(classcode: classcode, displayName: displayName, password: password))
        }

        createdStudents = created
        didCreate = true
    }
}
