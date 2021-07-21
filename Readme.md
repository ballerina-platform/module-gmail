# Ballerina Gmail Connector

[![Build Status](https://github.com/ballerina-platform/module-ballerinax-googleapis.gmail/workflows/CI/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-googleapis.gmail/actions?query=workflow%3ACI)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerinax-googleapis.gmail.svg)](https://github.com/ballerina-platform/module-ballerinax-googleapis.gmail/commits/master)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

[Gmail](https://blog.google/products/gmail/), short for Google Mail is a free email service developed by Google LLC. It
enables users to send and receive emails over the Internet.

Gmail connector connects to Gmail API from [Ballerina](https://ballerina.io/). 

For more information, go to the module(s).

- [`ballerinax/googleapis.gmail`](https://docs.central.ballerina.io/ballerinax/googleapis.gmail/0.99.11)
- [`ballerinax/googleapis.gmail.listener`](https://docs.central.ballerina.io/ballerinax/googleapis.gmail.listener/0.99.11)


## Building from the Source

### Setting Up the Prerequisites

1. Download and install Java SE Development Kit (JDK) version 11 (from one of the following locations).

   * [Oracle](https://www.oracle.com/java/technologies/javase-jdk11-downloads.html)

   * [OpenJDK](https://adoptopenjdk.net/)

        > **Note:** Set the JAVA_HOME environment variable to the path name of the directory into which you installed JDK.

2. Download and install [Ballerina Swan Lake Beta2](https://ballerina.io/). 

3. Download and install gradle.

4. Export Github Personal access token with read package permissions as follows,

```
 export packageUser=<Username>
 export packagePAT=<Personal access token>
 ```

### Building the Source

To clone the repository: Clone this repository using the following command:
```
git clone https://github.com/ballerina-platform/module-ballerinax-googleapis.gmail.git
```
#### Building java libraries
To build java libraries execute the following command.
```
 ./gradlew clean build
 ````

#### Build ballerina connector.

Execute the commands below to build from the source after installing Ballerina Swan Lake Beta2.

1. To build the library:
    * Move into gmail directory 
        ```shell script
            cd gmail
        ```
    * Build the ballerina package
        ```shell script
            bal build -c
        ```

2. To build the module without the tests:
```shell script
    bal build -c --skip-tests ./gmail
```

## Contributing to Ballerina

As an open source project, Ballerina welcomes contributions from the community. 

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of Conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful Links

* Discuss the code changes of the Ballerina project in [ballerina-dev@googlegroups.com](mailto:ballerina-dev@googlegroups.com).
* Chat live with us via our [Slack channel](https://ballerina.io/community/slack/).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
