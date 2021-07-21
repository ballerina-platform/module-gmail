// Copyright (c) 2021 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;

class MessageStream {
    private Message[] currentEntries = [];
    private int index = 0;
    private final http:Client httpClient;
    private final string userEmailId;
    private final MsgSearchFilter? filter;
    private string? pageToken = ();


    isolated function init(http:Client httpClient, string userId, MsgSearchFilter? filter) returns error? {
        self.httpClient = httpClient;
        self.filter = filter;
        if (self.filter?.pageToken is string) {
            self.pageToken = <string>self.filter?.pageToken;
        }
        self.userEmailId = userId;
        self.currentEntries = check self.fetchMessages();
    }

    public isolated function next() returns @tainted record {| Message value; |}|error? {
        if (self.index < self.currentEntries.length()) {
            record {| Message value; |} message = {value: self.currentEntries[self.index]};
            self.index += 1;
            return message;
        }
        if (self.pageToken is string) {
            self.index = 0;
            self.currentEntries = check self.fetchMessages();
            record {| Message value; |} message = {value: self.currentEntries[self.index]};
            self.index += 1;
            return message;
        }
    }

    isolated function fetchMessages() returns @tainted Message[]|error {
        string getListMessagesPath = USER_RESOURCE + self.userEmailId + MESSAGE_RESOURCE;
        string uriParams = check getURIParamsFromFilter(self.filter, self.pageToken);
        getListMessagesPath = getListMessagesPath + <@untainted>uriParams;
        http:Response httpResponse = <http:Response> check self.httpClient->get(getListMessagesPath);        
        json jsonlistMsgResponse = check handleResponse(httpResponse);
        MessageListPage|error response = jsonlistMsgResponse.cloneWithType(MessageListPage);

        if (response is MessageListPage) {
            self.pageToken = response?.nextPageToken;
            var messages = response?.messages;
            if (messages is Message[]) {
                return messages;
            }
            return [];
        } else {
            return error(ERR_MESSAGE_LIST, response);
        }
    }
}

class ThreadStream {
    private MailThread[] currentEntries = [];
    private int index = 0;
    private final http:Client httpClient;
    private final string userEmailId;
    private final MsgSearchFilter? filter;
    private string? pageToken = ();


    isolated function init(http:Client httpClient, string userId, MsgSearchFilter? filter) returns error? {
        self.httpClient = httpClient;
        self.filter = filter;
        if (self.filter?.pageToken is string) {
            self.pageToken = <string>self.filter?.pageToken;
        }
        self.userEmailId = userId;
        self.currentEntries = check self.fetchThreads();
    }

    public isolated function next() returns @tainted record {| MailThread value; |}|error? {
        if (self.index < self.currentEntries.length()) {
            record {| MailThread value; |} thread = {value: self.currentEntries[self.index]};
            self.index += 1;
            return thread;
        }
        if (self.pageToken is string) {
            self.index = 0;
            self.currentEntries = check self.fetchThreads();
            record {| MailThread value; |} thread = {value: self.currentEntries[self.index]};
            self.index += 1;
            return thread;
        }
    }

    isolated function fetchThreads() returns @tainted MailThread[]|error {
        string getListThreadPath = USER_RESOURCE + self.userEmailId + THREAD_RESOURCE;
        string uriParams = check getURIParamsFromFilter(self.filter, self.pageToken);
        getListThreadPath = getListThreadPath + <@untainted>uriParams;
        http:Response httpResponse = <http:Response> check self.httpClient->get(getListThreadPath);
        json jsonListThreadResponse = check handleResponse(httpResponse);
        ThreadListPage|error response = jsonListThreadResponse.cloneWithType(ThreadListPage);

        if (response is ThreadListPage) {
            self.pageToken = response?.nextPageToken;
            var threads = response?.threads;
            if (threads is MailThread[]) {
                return threads;
            }
            return [];
        } else {
            return error(ERR_THREAD_LIST, response);
        }
    }
}

class DraftStream {
    private Draft[] currentEntries = [];
    private int index = 0;
    private final http:Client httpClient;
    private final string userEmailId;
    private final DraftSearchFilter? filter;
    private string? pageToken = ();


    isolated function init(http:Client httpClient, string userId, DraftSearchFilter? filter) returns error? {
        self.httpClient = httpClient;
        self.filter = filter;
        if (self.filter?.pageToken is string) {
            self.pageToken = <string>self.filter?.pageToken;
        }
        self.userEmailId = userId;
        self.currentEntries = check self.fetchDrafts();
    }

    public isolated function next() returns @tainted record {| Draft value; |}|error? {
        if (self.index < self.currentEntries.length()) {
            record {| Draft value; |} draft = {value: self.currentEntries[self.index]};
            self.index += 1;
            return draft;
        }
        if (self.pageToken is string) {
            self.index = 0;
            self.currentEntries = check self.fetchDrafts();
            record {| Draft value; |} draft = {value: self.currentEntries[self.index]};
            self.index += 1;
            return draft;
        }
    }

    isolated function fetchDrafts() returns @tainted Draft[]|error {
        string getListDraftsPath = USER_RESOURCE + self.userEmailId + DRAFT_RESOURCE;
        string uriParams = check getURIParamsFromFilter(self.filter, self.pageToken);
        getListDraftsPath += <@untainted>uriParams;
        http:Response httpResponse = <http:Response> check self.httpClient->get(getListDraftsPath);
        json jsonListDraftResponse = check handleResponse(httpResponse);
        DraftListPage|error response = jsonListDraftResponse.cloneWithType(DraftListPage);

        if (response is DraftListPage) {
            self.pageToken = response?.nextPageToken;
            var drafts = response?.drafts;
            if (drafts is Draft[]) {
                return drafts;
            }
            return [];
        } else {
            return error(ERR_DRAFT_LIST, response);
        }
    }
}

public class MailboxHistoryStream {
    private History[] currentEntries = [];
    private int index = 0;
    private final http:Client httpClient;
    private final string userEmailId;
    private final string startHistoryId;
    private final string[]? historyTypes;
    private final string? labelId;
    private final string? maxResults;
    private string? pageToken = ();


    public isolated function init(http:Client httpClient, string userId, string startHistoryId, string[]? historyTypes,
                                    string? labelId, string? maxResults, string? pageToken) returns error? {
        self.httpClient = httpClient;
        self.userEmailId = userId;
        self.startHistoryId = startHistoryId;
        self.historyTypes = historyTypes;
        self.labelId = labelId;
        self.maxResults = maxResults;
        self.pageToken = pageToken;
        self.currentEntries = check self.fetchHistory();
    }

    public isolated function next() returns @tainted record {| History value; |}|error? {
        if (self.index < self.currentEntries.length()) {
            record {| History value; |} history = {value: self.currentEntries[self.index]};
            self.index += 1;
            return history;
        }
        if (self.pageToken is string) {
            self.index = 0;
            self.currentEntries = check self.fetchHistory();
            record {| History value; |} history = {value: self.currentEntries[self.index]};
            self.index += 1;
            return history;
        }
    }

    isolated function fetchHistory() returns @tainted History[]|error {

        string uriParams = "";
        uriParams = check appendEncodedURIParameter(uriParams, START_HISTORY_ID, self.startHistoryId);
        if (self.historyTypes is string[]) {
            foreach string historyType in <string[]>self.historyTypes {
                uriParams = check appendEncodedURIParameter(uriParams, HISTORY_TYPES, historyType);
            }
        }
        if (self.labelId is string) {
            uriParams = check appendEncodedURIParameter(uriParams, LABEL_ID, <string>self.labelId);
        }
        if (self.maxResults is string) {
            uriParams = check appendEncodedURIParameter(uriParams, MAX_RESULTS, <string>self.maxResults);
        }
        if (self.pageToken is string) {
            uriParams = check appendEncodedURIParameter(uriParams, PAGE_TOKEN, <string>self.pageToken);
        }
        string listHistoryPath = USER_RESOURCE + self.userEmailId + HISTORY_RESOURCE + uriParams;
        http:Response httpResponse = <http:Response> check self.httpClient->get(listHistoryPath);
        json jsonHistoryResponse = check handleResponse(httpResponse);      
        MailboxHistoryPage|error response = jsonHistoryResponse.cloneWithType(MailboxHistoryPage);

        if (response is MailboxHistoryPage) {
            self.pageToken = response?.nextPageToken;
            var history = response?.history;
            if (history is History[]) {
                foreach History historyRecord in history {
                    historyRecord.historyId = response.historyId;
                }
                return history;
            }
            return [{historyId : response.historyId}];
        } else {
            return error(ERR_MAILBOX_HISTORY_LIST, response);
        }
    }
}

isolated function getURIParamsFromFilter(Filter? filter, string? pageToken) returns string|error {
    string uriParams = "";
    if (filter is Filter) {
        uriParams = filter?.includeSpamTrash is boolean ? check appendEncodedURIParameter(uriParams, INCLUDE_SPAMTRASH, 
                    string `${<boolean>filter?.includeSpamTrash}`) : uriParams;        
        uriParams = filter?.maxResults is int ? check appendEncodedURIParameter(uriParams, MAX_RESULTS,
                    filter?.maxResults.toString()) : uriParams;        
        uriParams = filter?.q is string ? check appendEncodedURIParameter(uriParams, QUERY, <string>filter?.q) : 
                    uriParams;
    }
    if (filter is MsgSearchFilter) {
        if (filter?.labelIds is string[]) {
            foreach string labelId in <string[]>filter?.labelIds {
                uriParams = check appendEncodedURIParameter(uriParams, LABEL_IDS, labelId);
            }
        }
    }
    uriParams = pageToken is string ? check appendEncodedURIParameter(uriParams, PAGE_TOKEN, <string>pageToken) :
                uriParams;
    return uriParams;
}
