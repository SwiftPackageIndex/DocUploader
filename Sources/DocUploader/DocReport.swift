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

import AsyncHTTPClient
import Dependencies
import DocUploadBundle
import NIOHTTP1


enum DocReport {

    @Dependency(\.httpClient) static var httpClient: HTTPExecutor

    enum Status: String, Codable {
        case ok
        case failed
        case skipped
    }

    struct PostDocReportDTO: Codable {
        var docArchives: [DocArchive]
        var error: String?
        var fileCount: Int?
        var linkablePathsCount: Int?
        var logUrl: String?
        var mbSize: Int?
        var status: Status
    }

    static func request(apiBaseURL: String, apiToken: String, buildId: UUID, dto: PostDocReportDTO) throws -> HTTPClientRequest {
        let baseURL = apiBaseURL.ensuringSchemePrefix.ensuringAPISuffix
        var req = HTTPClientRequest(url: "\(baseURL)/builds/\(buildId)/doc-report")
        req.method = .POST
        req.headers.add(name: "Authorization", value: "Bearer \(apiToken)")
        req.headers.add(name: "Content-Type", value: "application/json")
        let data = try JSONEncoder().encode(dto)
        req.body = .bytes(.init(data: data))
        return req
    }

    static func reportResult(client: HTTPClient, apiBaseURL: String, apiToken: String, buildId: UUID, dto: PostDocReportDTO) async throws -> HTTPResponseStatus {
        let req = try request(apiBaseURL: apiBaseURL, apiToken: apiToken, buildId: buildId, dto: dto)
        let res = try await httpClient.execute(client, req, timeout: .seconds(10))
        return res.status
    }

}


extension String {
    var ensuringSchemePrefix: String {
        if hasPrefix("https://") || hasPrefix("http://") {
            return self
        } else {
            return "https://" + self
        }
    }

    var ensuringAPISuffix: String {
        if hasSuffix("/api") {
            return self
        } else {
            return self + "/api"
        }
    }
}
