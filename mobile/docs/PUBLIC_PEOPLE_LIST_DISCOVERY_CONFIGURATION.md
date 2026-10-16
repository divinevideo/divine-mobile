# Public people-list discovery configuration

Public search and Explore hide protocol-reserved lists, generic client machinery,
and deployment-owned excluded d-tags. Deployment-owned values are supplied outside
source control; code and fixtures use no identifying external values.

Release and web build pipelines must supply `DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS`
as a JSON array of exact nonblank d-tag strings through the existing external build
configuration. The coordinated release pipeline validates this input before building
and passes it through `--dart-define-from-file`. Keep the same policy on native
releases, web builds, Shorebird releases and patches. A missing or malformed policy
must stop a release build; a missing default does not retain the production policy.
An explicit `[]` deliberately removes additional exclusions. See
[the build policy guide](PUBLIC_PEOPLE_LIST_POLICY.md) for configuration storage,
validation, and local build instructions.

Local development without the input reports a diagnostic and applies only the
generic protocol and client-machinery filters. Use the same externally supplied
policy for local or preview validation intended to match production discovery.
A synthetic local value, such as `["synthetic-machine-set"]`, is suitable for tests.

`PeopleListsRepositoryImpl` copies the configured set into an immutable policy.
It applies exclusions after selecting the newest revision for each coordinate and
only at the discovery/search boundary. Owner synchronization, explicit coordinate
reads, and owner edit flows keep their normal behavior. Gallery author blocking
controls card visibility and does not change roster-wide counts or authoritative
zero totals.
