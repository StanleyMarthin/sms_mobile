import re

with open('/home/sahrulr/StudioProjects/sm_workshop/lib/features/job_plan/presentation/pages/job_plan_page.dart', 'r') as f:
    code = f.read()

# 1. Add SingleTickerProviderStateMixin
code = code.replace(
    'class _JobPlanPageState extends State<JobPlanPage> {',
    'class _JobPlanPageState extends State<JobPlanPage> with SingleTickerProviderStateMixin {'
)

# 2. Add TabController variable
code = re.sub(
    r'(late final JobPlanRepository _repository;)',
    r'\1\n  late TabController _tabController;\n  late bool _showPlanTab;\n  late bool _canCreate;',
    code
)

# 3. Initialize TabController in initState
init_old = '''  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();
    _woRepository = sl<WorkOrderRepository>();'''

init_new = '''  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();
    _woRepository = sl<WorkOrderRepository>();
    
    final session = sl<SessionManager>();
    final isKpApprovalOnly =
        hasPermission(session.role, Permission.approvePlanKp) &&
        !hasPermission(session.role, Permission.createPlan) &&
        !hasPermission(session.role, Permission.dashboardAdvisor);
    final isMpApprovalOnly =
        hasPermission(session.role, Permission.approvePlanMp) &&
        !hasPermission(session.role, Permission.createPlan) &&
        !hasPermission(session.role, Permission.dashboardAdvisor);
    
    _showPlanTab = !isKpApprovalOnly && !isMpApprovalOnly;
    _canCreate = hasPermission(session.role, Permission.createPlan);
    _tabController = TabController(length: _showPlanTab ? 2 : 1, vsync: this);
'''
code = code.replace(init_old, init_new)

# 4. Dispose TabController
dispose_old = '''  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }'''

dispose_new = '''  @override
  void dispose() {
    _tabController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }'''
code = code.replace(dispose_old, dispose_new)

# 5. Build method: remove DefaultTabController
# First, find the start of the build method
build_old = '''  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final canCreate = hasPermission(session.role, Permission.createPlan);

    // If role only has approval permission and NOTHING else (like KD / MP strictly for approval),
    // we only show the "Approval" tab. Otherwise, show both.
    final isKpApprovalOnly =
        hasPermission(session.role, Permission.approvePlanKp) &&
        !hasPermission(session.role, Permission.createPlan) &&
        !hasPermission(session.role, Permission.dashboardAdvisor);
    final isMpApprovalOnly =
        hasPermission(session.role, Permission.approvePlanMp) &&
        !hasPermission(session.role, Permission.createPlan) &&
        !hasPermission(session.role, Permission.dashboardAdvisor);
    final showPlanTab = !isKpApprovalOnly && !isMpApprovalOnly;

    return DefaultTabController(
      length: showPlanTab ? 2 : 1,
      child: Scaffold('''

build_new = '''  @override
  Widget build(BuildContext context) {
    return Scaffold('''
code = code.replace(build_old, build_new)

# Remove the trailing parenthesis and comma from DefaultTabController
# Wait, at the end of the build method:
end_old = '''  }

  // ── Source Selection Sheet ─────────────────────────────────'''
# The last part of build is probably:
#           ],
#         ),
#       ),
#     );
#   }
# We need to drop the DefaultTabController wrapper.
code = re.sub(
    r'\s+body: Stack\(',
    r'\n        appBar: TabBar(\n          controller: _tabController,\n          labelColor: AppColors.gold,\n          unselectedLabelColor: AppColors.textMuted,\n          indicatorColor: AppColors.gold,\n          tabs: [\n            const Tab(text: "Approval Plan"),\n            if (_showPlanTab) const Tab(text: "Rencana"),\n          ],\n        ),\n        body: Stack(',
    code
)

code = re.sub(
    r'appBar: TabBar\(\s+labelColor:.*?(body: Stack)',
    r'\1',
    code,
    flags=re.DOTALL
)

# And now inject controller: _tabController into TabBarView
code = code.replace(
    'TabBarView(\n              key: const PageStorageKey("jobPlanTab"),', 
    'TabBarView(\n              controller: _tabController,\n              key: const PageStorageKey("jobPlanTab"),'
)

# Fix canCreate and showPlanTab references in the rest of build method
code = code.replace('canCreate', '_canCreate').replace('showPlanTab', '_showPlanTab')

# Find the closing parenthesis of DefaultTabController
code = re.sub(
    r'\n      \),\n    \);\n  \}\n\n  // ──',
    r'\n    );\n  }\n\n  // ──',
    code
)

with open('/home/sahrulr/StudioProjects/sm_workshop/lib/features/job_plan/presentation/pages/job_plan_page.dart', 'w') as f:
    f.write(code)

