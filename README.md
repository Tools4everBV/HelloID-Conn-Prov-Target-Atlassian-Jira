# HelloID-Conn-Prov-Target-Atlassian-Jira

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

<br />

## Versioning
| Version | Description | Date |
| - | - | - |
| 1.1.0   | Updated with group management | 2022/12/15  |
| 1.0.0   | Initial release | 2021/04/02  |

<!-- TABLE OF CONTENTS -->
## Table of Contents
- [Versioning](#versioning)
- [Table of Contents](#table-of-contents)
- [Introduction](#introduction)
- [Connection settings](#connection-settings)
- [Getting help](#getting-help)
- [HelloID Docs](#helloid-docs)

## Introduction
The interface to communicate with Jira is via the API. Please see https://developer.atlassian.com/cloud/jira/platform/rest/v3/ for more information about the API.

With this connector you can create and delete accounts. Furthermore you can assign/unassign group memberships to Jira groups.


## Connection settings
The following settings are required to connect to the API.

| Setting     | Description |
| ------------ | ----------- |
| Jira Url | Example: https://customer.atlassian.net |
| Username | User with permissions to create account |
| Password | Password of the user |

## Getting help
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012518799-How-to-add-a-target-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-users/#api-rest-api-3-user-post

# HelloID Docs
The official HelloID documentation can be found at: https://docs.helloid.com/
