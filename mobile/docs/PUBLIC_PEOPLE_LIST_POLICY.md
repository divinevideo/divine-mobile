# Public people-list discovery policy

App-managed protocol lists remain excluded by the codec. Additional public
discovery/search exclusions come from the JSON-array build define
`DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS`. The repository copies the configured
set into immutable storage. Owner synchronization and explicit list-coordinate
reads remain unaffected.

Identifying policy values belong in configuration, not code, fixtures, or PR
comments. The existing production exclusion is stored in the GitHub repository
variable with the same name. Actions web builds read that variable. Codemagic
store releases, patches, and macOS artifacts read it using their existing
`github_credentials` token, or accept an explicit environment override. The token
must be able to read repository Actions variables. No new environment group is
required.

`scripts/write_public_people_list_defines.py` validates the array before writing
or merging a dart-defines file. Missing/malformed policy or failed configuration
access stops these artifact builds. An explicit `[]` deliberately means no
additional exclusions. Validation errors do not print configuration values or
existing release defines. Shorebird provenance includes the resolved policy;
patch configuration must still match the selected release fingerprint.

For a local build that should use the configured production policy:

```sh
python3 scripts/write_public_people_list_defines.py \
  --output build/public_people_list_defines.json \
  --github-repository divinevideo/divine-mobile
flutter run --dart-define-from-file=build/public_people_list_defines.json
```

Alternatively provide the JSON array through the environment before running the
writer. Ordinary developer builds without the define use no additional
exclusions and emit a configuration diagnostic; they do not establish that the
production policy was exercised. Runtime parsing also diagnoses malformed
defines without revealing their values.

When updating policy, verify both public discovery/search filtering and explicit
owner/coordinate reads. Capture the build revision and resolved configuration
through the existing build provenance rather than placing identifying values in
review evidence.
