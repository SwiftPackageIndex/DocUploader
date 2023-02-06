// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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


import Foundation

import Logging


enum Retry {
    static func delay(retryCount: Int, interval: TimeInterval = 5) -> UInt32 {
        (pow(2, max(0, retryCount - 1)) * Decimal(interval) as NSDecimalNumber).uint32Value
    }

    enum Result {
        case success
        case failure
    }

    enum Error: Swift.Error {
        case timeout
    }

    static func repeatedly(_ label: String, logger: Logger, retries: Int = 5, interval: TimeInterval = 5, _ block: () async throws -> Result) async throws {
        var currentTry = 1
        while currentTry <= retries {
            logger.info("\(label) (attempt \(currentTry))")
            if try await block() == .success { return }
            let wait = delay(retryCount: currentTry, interval: interval)
            logger.info("Retrying in \(wait) seconds ...")
            sleep(wait)
            currentTry += 1
        }
        throw Error.timeout
    }
}
