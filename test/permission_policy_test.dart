import 'package:flutter_test/flutter_test.dart';
import 'package:reportini/data/local/seed.dart';
import 'package:reportini/data/models/account.dart';
import 'package:reportini/data/models/report.dart';
import 'package:reportini/data/permission_policy.dart';

void main() {
  const policy = PermissionPolicy();
  final now = DateTime(2026);
  final [admin, agent, otherAgent, citizen] = demoAccounts(now);
  final report = demoReports(now).first;
  final disabled = Account(
    id: agent.id,
    name: agent.name,
    email: agent.email,
    role: AccountRole.agent,
    municipalityId: agent.municipalityId,
    createdAt: now,
    enabled: false,
  );

  test('report reads respect role, ownership and municipality', () {
    expect(policy.canReadReport(admin, report), isTrue);
    expect(policy.canReadReport(agent, report), isTrue);
    expect(policy.canReadReport(citizen, report), isTrue);
    expect(policy.canReadReport(otherAgent, report), isFalse);
    expect(policy.canReadReport(disabled, report), isFalse);
    expect(policy.canReadReport(null, report), isFalse);
  });

  test('report creation checks citizen identity and initial status', () {
    expect(
      policy.canCreateReport(citizen, citizen.id, ReportStatus.enAttente),
      isTrue,
    );
    expect(
      policy.canCreateReport(citizen, agent.id, ReportStatus.enAttente),
      isFalse,
    );
    expect(
      policy.canCreateReport(citizen, citizen.id, ReportStatus.enCours),
      isFalse,
    );
    expect(
      policy.canCreateReport(agent, agent.id, ReportStatus.enAttente),
      isFalse,
    );
  });

  test('status updates and administration are independently scoped', () {
    expect(policy.canChangeStatus(admin, report), isTrue);
    expect(policy.canChangeStatus(agent, report), isTrue);
    expect(policy.canChangeStatus(otherAgent, report), isFalse);
    expect(policy.canChangeStatus(disabled, report), isFalse);
    expect(policy.canChangeStatus(citizen, report), isFalse);
    expect(policy.canManage(admin), isTrue);
    expect(policy.canManage(agent), isFalse);
    expect(policy.canEditName(citizen, citizen.id), isTrue);
    expect(policy.canEditName(citizen, admin.id), isFalse);
  });
}
