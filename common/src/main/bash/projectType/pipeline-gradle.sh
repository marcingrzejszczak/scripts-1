#!/bin/bash
set -e

function build() {
    echo "Additional Build Options [${BUILD_OPTIONS}]"

    if [[ "${CI}" == "CONCOURSE" ]]; then
        # shellcheck disable=SC2086
        ./gradlew clean build deploy -PnewVersion="${PIPELINE_VERSION}" -DREPO_WITH_BINARIES="${REPO_WITH_BINARIES}" --stacktrace ${BUILD_OPTIONS} || ( printTestResults && return 1)
    else
        # shellcheck disable=SC2086
        ./gradlew clean build deploy -PnewVersion="${PIPELINE_VERSION}" -DREPO_WITH_BINARIES="${REPO_WITH_BINARIES}" --stacktrace ${BUILD_OPTIONS}
    fi
}

function apiCompatibilityCheck() {
    echo "Running retrieval of group and artifactid to download all dependencies. It might take a while..."

    # Find latest prod version
    LATEST_PROD_TAG=$( findLatestProdTag )
    echo "Last prod tag equals ${LATEST_PROD_TAG}"
    if [[ -z "${LATEST_PROD_TAG}" ]]; then
        echo "No prod release took place - skipping this step"
    else
        # Downloading latest jar
        LATEST_PROD_VERSION=${LATEST_PROD_TAG#prod/}
        echo "Last prod version equals ${LATEST_PROD_VERSION}"
        echo "Additional Build Options [${BUILD_OPTIONS}]"
        if [[ "${CI}" == "CONCOURSE" ]]; then
            # shellcheck disable=SC2086
            ./gradlew clean apiCompatibility -DlatestProductionVersion="${LATEST_PROD_VERSION}" -DREPO_WITH_BINARIES="${REPO_WITH_BINARIES}" --stacktrace ${BUILD_OPTIONS} || ( printTestResults && return 1)
        else
            # shellcheck disable=SC2086
            ./gradlew clean apiCompatibility -DlatestProductionVersion="${LATEST_PROD_VERSION}" -DREPO_WITH_BINARIES="${REPO_WITH_BINARIES}" --stacktrace ${BUILD_OPTIONS}
        fi
    fi
}

function retrieveGroupId() {
    ./gradlew groupId -q | tail -1
}

function retrieveAppName() {
    ./gradlew artifactId -q | tail -1
}

function printTestResults() {
    # shellcheck disable=SC1117
    echo -e "\n\nBuild failed!!! - will print all test results to the console (it's the easiest way to debug anything later)\n\n" && tail -n +1 "$( testResultsAntPattern )"
}

function retrieveStubRunnerIds() {
    ./gradlew stubIds -q | tail -1
}

function runSmokeTests() {
    local applicationUrl="${APPLICATION_URL}"
    local stubrunnerUrl="${STUBRUNNER_URL}"
    echo "Running smoke tests"

    if [[ "${CI}" == "CONCOURSE" ]]; then
        # shellcheck disable=SC2086
        ./gradlew smoke -PnewVersion="${PIPELINE_VERSION}" -Dapplication.url="${applicationUrl}" -Dstubrunner.url="${stubrunnerUrl}" ${BUILD_OPTIONS} || ( printTestResults && return 1)
    else
        # shellcheck disable=SC2086
        ./gradlew smoke -PnewVersion="${PIPELINE_VERSION}" -Dapplication.url="${applicationUrl}" -Dstubrunner.url="${stubrunnerUrl}" ${BUILD_OPTIONS}
    fi
}

function runE2eTests() {
    local applicationUrl="${APPLICATION_URL}"
    echo "Running e2e tests"

    if [[ "${CI}" == "CONCOURSE" ]]; then
        # shellcheck disable=SC2086
        ./gradlew e2e -PnewVersion="${PIPELINE_VERSION}" -Dapplication.url="${applicationUrl}" ${BUILD_OPTIONS} || ( printTestResults && return 1)
    else
        # shellcheck disable=SC2086
        ./gradlew e2e -PnewVersion="${PIPELINE_VERSION}" -Dapplication.url="${applicationUrl}" ${BUILD_OPTIONS}
    fi
}

function outputFolder() {
    echo "build/libs"
}

function testResultsAntPattern() {
    echo "**/test-results/*.xml"
}

export -f build
export -f apiCompatibilityCheck
export -f runSmokeTests
export -f runE2eTests
export -f outputFolder
export -f testResultsAntPattern
