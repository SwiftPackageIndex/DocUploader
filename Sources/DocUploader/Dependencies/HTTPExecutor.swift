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

import AsyncHTTPClient
import Dependencies
import NIO


struct HTTPExecutor {
    var execute: (_ client: HTTPClient, _ request: HTTPClientRequest, _ timeout: TimeAmount) async throws -> HTTPClientResponse
}

extension HTTPExecutor {
    func execute(_ client: AsyncHTTPClient.HTTPClient, _ request: AsyncHTTPClient.HTTPClientRequest, timeout: NIOCore.TimeAmount) async throws -> HTTPClientResponse {
        try await execute(client, request, timeout)
    }
}

extension HTTPExecutor {
    static var live: Self {
        .init { client, request, timeout in
            try await client.execute(request, timeout: timeout)
        }
    }
}

extension HTTPExecutor: DependencyKey {
    static var liveValue: HTTPExecutor {
        .live
    }
}

extension DependencyValues {
    var httpClient: HTTPExecutor {
        get { self[HTTPExecutor.self] }
        set { self[HTTPExecutor.self] = newValue }
    }
}
