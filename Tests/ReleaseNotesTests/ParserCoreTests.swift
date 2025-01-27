// Copyright 2022 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import ReleaseNotesCore
import XCTest
import Parsing


final class ParserCoreTests: XCTestCase {

    func test_progressLine() throws {
        do {
            var input = "Updating https://github.com/pointfreeco/swift-parsing\n"[...]
            XCTAssertNotNil(Parser.progressLine.parse(&input))
            XCTAssertEqual(input, "")
        }
        do {
            var input = "Updated https://github.com/apple/swift-argument-parser (0.81s)\n"[...]
            XCTAssertNotNil(Parser.progressLine.parse(&input))
            XCTAssertEqual(input, "")
        }
        do {
            var input = "Computing version for https://github.com/pointfreeco/swift-parsing\n"[...]
            XCTAssertNotNil(Parser.progressLine.parse(&input))
            XCTAssertEqual(input, "")
        }
        do {
            var input = "Computed https://github.com/pointfreeco/swift-parsing at 0.4.1 (0.02s)\n"[...]
            XCTAssertNotNil(Parser.progressLine.parse(&input))
            XCTAssertEqual(input, "")
        }
        do {
            var input = "Creating working copy for https://github.com/JohnSundell/Plot.git\n"[...]
            XCTAssertNotNil(Parser.progressLine.parse(&input))
            XCTAssertEqual(input, "")
        }
        do {
            var input = "Working copy of https://github.com/JohnSundell/Plot.git resolved at 0.10.0\n"[...]
            XCTAssertNotNil(Parser.progressLine.parse(&input))
            XCTAssertEqual(input, "")
        }
    }

    func test_anyProgress() throws {
        var input = """
            Updating https://github.com/pointfreeco/swift-parsing
            Updating https://github.com/apple/swift-argument-parser
            Updating https://github.com/SwiftPackageIndex/SemanticVersion
            Updated https://github.com/apple/swift-argument-parser (0.81s)
            Updated https://github.com/pointfreeco/swift-parsing (0.81s)
            Updated https://github.com/SwiftPackageIndex/SemanticVersion (0.81s)
            Computing version for https://github.com/pointfreeco/swift-parsing
            Computed https://github.com/pointfreeco/swift-parsing at 0.4.1 (0.02s)
            Computing version for https://github.com/SwiftPackageIndex/SemanticVersion
            Computed https://github.com/SwiftPackageIndex/SemanticVersion at 0.3.1 (0.01s)
            Computing version for https://github.com/apple/swift-argument-parser
            Computed https://github.com/apple/swift-argument-parser at 1.0.2 (0.01s)
            Creating working copy for https://github.com/JohnSundell/Plot.git
            Working copy of https://github.com/JohnSundell/Plot.git resolved at 0.10.0

            """[...]
        XCTAssertNotNil(Skip(Parser.progress).parse(&input))
        XCTAssertEqual(input, "")
    }

    func test_dependencyCount() throws {
        do {
            var input = "1 dependency has changed:"[...]
            XCTAssertEqual(Parser.dependencyCount.parse(&input), 1)
            XCTAssertEqual(input, "")
        }
        do {
            var input = "12 dependencies have changed:"[...]
            XCTAssertEqual(Parser.dependencyCount.parse(&input), 12)
            XCTAssertEqual(input, "")
        }
        do {
            var input = "0 dependencies have changed."[...]
            XCTAssertEqual(Parser.dependencyCount.parse(&input), 0)
            XCTAssertEqual(input, "")
        }
    }

    func test_upToStart() throws {
        do {
            var input = "~ foo"[...]
            XCTAssertNotNil(Parser.upToStart.parse(&input))
            XCTAssertEqual(input, "~ foo")
        }
        do {
            var input = "+ foo"[...]
            XCTAssertNotNil(Parser.upToStart.parse(&input))
            XCTAssertEqual(input, "+ foo")
        }
        do {
            var input = "other"[...]
            XCTAssertNotNil(Parser.upToStart.parse(&input))
            XCTAssertEqual(input, "")
        }
    }

    func test_semanticVersion() throws {
        do {
            var input = "1.2.3"[...]
            XCTAssertEqual(Parser.semanticVersion.parse(&input),
                           .tag(.init(1, 2, 3)))
            XCTAssertEqual(input, "")
        }
        do {
            var input = "1.2.3-b1"[...]
            XCTAssertEqual(Parser.semanticVersion.parse(&input),
                           .tag(.init("1.2.3-b1")!))
            XCTAssertEqual(input, "")
        }
    }

    func test_revision() throws {
        do {
            var input = "1.2.3"[...]
            XCTAssertEqual(Parser.revision.parse(&input), .tag(.init(1, 2, 3)))
            XCTAssertEqual(input, "")
        }
        do {
            var input = "main"[...]
            XCTAssertEqual(Parser.revision.parse(&input), .branch("main"))
            XCTAssertEqual(input, "")
        }
    }

    func test_newPackage() throws {
        do {
            var input = "+ swift-collections 1.0.2"[...]
            XCTAssertEqual(Parser.newPackage.parse(&input), .init(packageName: "swift-collections"))
            XCTAssertEqual(input, "")
        }
        do {
            var input = "~ swift-collections 1.0.2"[...]
            XCTAssertNil(Parser.newPackage.parse(&input))
            XCTAssertEqual(input, "~ swift-collections 1.0.2")
        }
    }

    func test_update() throws {
        do {
            var input = #"~ swift-tools-support-core main -> swift-tools-support-core Revision(identifier: "4afd18e40eb028cd9fbe7342e3f98020ea9fdf1a") main"#[...]
            XCTAssertEqual(Parser.update.parse(&input),
                           .init(packageName: "swift-tools-support-core",
                                 oldRevision: .branch("main")))
            XCTAssertEqual(input, "")
        }
        do {
            var input = #"~ vapor 4.54.0 -> vapor 4.54.1"#[...]
            XCTAssertEqual(Parser.update.parse(&input),
                           .init(packageName: "vapor",
                                 oldRevision: .tag(.init(4, 54, 0))))
            XCTAssertEqual(input, "")
        }
        do {
            var input = "+ swift-collections 1.0.2"[...]
            XCTAssertEqual(Parser.update.parse(&input),
                           .init(packageName: "swift-collections"))
            XCTAssertEqual(input, "")
        }
    }

    func test_updates() throws {
        do {
            var input = #"~ vapor 4.54.0 -> vapor 4.54.1"#[...]
            XCTAssertEqual(Parser.updates.parse(&input),
                           [.init(packageName: "vapor",
                                 oldRevision: .tag(.init(4, 54, 0)))])
            XCTAssertEqual(input, "")
        }
        do {
            var input = "+ swift-collections 1.0.2"[...]
            XCTAssertEqual(Parser.updates.parse(&input),
                           [.init(packageName: "swift-collections")])
            XCTAssertEqual(input, "")
        }
        do {
            var input = """
            ~ vapor 4.54.0 -> vapor 4.54.1
            + swift-collections 1.0.2
            """[...]

            XCTAssertEqual(Parser.updates.parse(&input),
                           [.init(packageName: "vapor",
                                  oldRevision: .tag(.init(4, 54, 0))),
                            .init(packageName: "swift-collections")])
            XCTAssertEqual(input, "")
        }
        do {
            var input = """
            + swift-collections 1.0.2
            ~ vapor 4.54.0 -> vapor 4.54.1
            """[...]

            XCTAssertEqual(Parser.updates.parse(&input),
                           [.init(packageName: "swift-collections"),
                            .init(packageName: "vapor",
                                  oldRevision: .tag(.init(4, 54, 0)))])
            XCTAssertEqual(input, "")
        }
    }

    func test_updates_full_list() throws {
        var input = """
            + swift-collections 1.0.2
            ~ swift-tools-support-core main -> swift-tools-support-core Revision(identifier: "4afd18e40eb028cd9fbe7342e3f98020ea9fdf1a") main
            ~ vapor 4.54.0 -> vapor 4.54.1
            ~ swift-nio-ssl 2.17.1 -> swift-nio-ssl 2.17.2
            ~ swift-driver main -> swift-driver Revision(identifier: "fdafa379a28bc1567cc15b67b1fe55aa18ba04de") main
            ~ fluent-kit 1.19.0 -> fluent-kit 1.20.0
            ~ async-kit 1.11.0 -> async-kit 1.11.1
            ~ swift-nio-transport-services 1.11.3 -> swift-nio-transport-services 1.11.4
            ~ SwiftPM main -> SwiftPM Revision(identifier: "49ba6e97a60d1ea4f89c43503c7533e02c6d6913") main
            ~ swift-nio 2.36.0 -> swift-nio 2.37.0
            ~ llbuild main -> llbuild Revision(identifier: "db8311d7d284cae487dff582de980db5a918692f") main
            """[...]
        XCTAssertEqual(Parser.updates.parse(&input), [
            .init(packageName: "swift-collections"),
            .init(packageName: "swift-tools-support-core", oldRevision: .branch("main")),
            .init(packageName: "vapor", oldRevision: .tag(.init(4, 54, 0))),
            .init(packageName: "swift-nio-ssl", oldRevision: .tag(.init(2, 17, 1))),
            .init(packageName: "swift-driver", oldRevision: .branch("main")),
            .init(packageName: "fluent-kit", oldRevision: .tag(.init(1, 19, 0))),
            .init(packageName: "async-kit", oldRevision: .tag(.init(1, 11, 0))),
            .init(packageName: "swift-nio-transport-services", oldRevision: .tag(.init(1, 11, 3))),
            .init(packageName: "SwiftPM", oldRevision: .branch("main")),
            .init(packageName: "swift-nio", oldRevision: .tag(.init(2, 36, 0))),
            .init(packageName: "llbuild", oldRevision: .branch("main")),
        ])
        XCTAssertEqual(input, "")
    }

    func test_packageUpdate() throws {
        do {
            var input = """
            10 dependencies have changed:
            ~ swift-tools-support-core main -> swift-tools-support-core Revision(identifier: "4afd18e40eb028cd9fbe7342e3f98020ea9fdf1a") main
            ~ vapor 4.54.0 -> vapor 4.54.1
            ~ swift-nio-ssl 2.17.1 -> swift-nio-ssl 2.17.2
            ~ swift-driver main -> swift-driver Revision(identifier: "fdafa379a28bc1567cc15b67b1fe55aa18ba04de") main
            ~ fluent-kit 1.19.0 -> fluent-kit 1.20.0
            ~ async-kit 1.11.0 -> async-kit 1.11.1
            ~ swift-nio-transport-services 1.11.3 -> swift-nio-transport-services 1.11.4
            ~ SwiftPM main -> SwiftPM Revision(identifier: "49ba6e97a60d1ea4f89c43503c7533e02c6d6913") main
            ~ swift-nio 2.36.0 -> swift-nio 2.37.0
            ~ llbuild main -> llbuild Revision(identifier: "db8311d7d284cae487dff582de980db5a918692f") main
            """[...]
            XCTAssertEqual(Parser.packageUpdate.parse(&input)?.count, 10)
        }
        do {
            var input = """

            0 dependencies have changed.
            """[...]
            XCTAssertEqual(Parser.packageUpdate.parse(&input)?.count, 0)
        }
        do {
            var input = """
            Updating https://github.com/pointfreeco/swift-parsing
            Updating https://github.com/apple/swift-argument-parser
            Updating https://github.com/SwiftPackageIndex/SemanticVersion
            Updated https://github.com/apple/swift-argument-parser (0.81s)
            Updated https://github.com/pointfreeco/swift-parsing (0.81s)
            Updated https://github.com/SwiftPackageIndex/SemanticVersion (0.81s)
            Computing version for https://github.com/pointfreeco/swift-parsing
            Computed https://github.com/pointfreeco/swift-parsing at 0.4.1 (0.02s)
            Computing version for https://github.com/SwiftPackageIndex/SemanticVersion
            Computed https://github.com/SwiftPackageIndex/SemanticVersion at 0.3.1 (0.01s)
            Computing version for https://github.com/apple/swift-argument-parser
            Computed https://github.com/apple/swift-argument-parser at 1.0.2 (0.01s)

            0 dependencies have changed.
            """[...]
            XCTAssertEqual(Parser.packageUpdate.parse(&input)?.count, 0)
        }
    }

    func test_regression_new_package() throws {
        var input = """
        6 dependencies have changed:
        + swift-collections 1.0.2
        ~ fluent-postgres-driver 2.2.2 -> fluent-postgres-driver 2.2.3
        ~ swift-driver main -> swift-driver Revision(identifier: "a034b0bc0cc1366e289e25e00b3e0b21089c98fe") main
        ~ swift-tools-support-core main -> swift-tools-support-core Revision(identifier: "d318eaafe60f20be0f0bbc658793f64bf83847d8") main
        ~ swift-argument-parser 1.0.2 -> swift-argument-parser 1.0.3
        ~ SwiftPM main -> SwiftPM Revision(identifier: "658654765f5a7dfb3456c37dafd3ed8cd8b363b4") main
        """[...]
        XCTAssertEqual(Parser.packageUpdate.parse(&input)?.count, 6)
    }

    func test_progress_resilience() throws {
        // Ensure random output before the dependency count line is ignored
        var input = """
            foo
            bar
            ~ something
            1 dependency has changed:
            ~ fluent-postgres-driver 2.2.2 -> fluent-postgres-driver 2.2.3
            """[...]
        XCTAssertEqual(Parser.packageUpdate.parse(&input)?.count, 1)
    }

}
