// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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
import ballerina/log;
import ballerinax/googleapis.gmail as gmail;

# Listener for Gmail Connector.
@display {label: "Gmail Listener"}
public class Listener {
    private string startHistoryId = "";
    private string topicResource = "";
    private string subscriptionResource = "";
    private string userId = ME;
    private gmail:GmailConfiguration gmailConfig;
    private http:Listener httpListener;
    private string project;
    private string pushEndpoint;

    private WatchRequestBody requestBody = {topicName: ""};
    private HttpService? httpService;
    http:Client pubSubClient;
    http:Client gmailHttpClient;

    public isolated function init(int port, gmail:GmailConfiguration gmailConfig, string project, string pushEndpoint, 
                                    GmailListenerConfiguration? listenerConfig = ()) returns @tainted error? {

        http:ClientSecureSocket? socketConfig = (listenerConfig is GmailListenerConfiguration) ? (listenerConfig
                                                    ?.secureSocketConfig) : (gmailConfig?.secureSocketConfig);
        // Create pubsub http client.
        self.pubSubClient = checkpanic new (PUBSUB_BASE_URL, {
            auth: (listenerConfig is GmailListenerConfiguration) ? (listenerConfig.authConfig) 
                    : (gmailConfig.oauthClientConfig),
            secureSocket: socketConfig
        });
        // Create gmail http client.
        self.gmailHttpClient = checkpanic new (gmail:BASE_URL, {
            auth: gmailConfig.oauthClientConfig,
            secureSocket: gmailConfig?.secureSocketConfig
        });

        self.httpListener = check new (port);
        //Create gmail connector client.
        self.gmailConfig = gmailConfig;
        self.project = project;
        self.pushEndpoint = pushEndpoint;

        TopicSubscriptionDetail topicSubscriptionDetail = check createTopic(self.pubSubClient, project, pushEndpoint);
        self.topicResource = topicSubscriptionDetail.topicResource;
        self.subscriptionResource = topicSubscriptionDetail.subscriptionResource;
        self.requestBody = {topicName: self.topicResource, labelIds: [INBOX], labelFilterAction: INCLUDE};

        self.httpService = ();
    }

    public isolated function attach(service object {} s, string[]|string? name = ()) returns @tainted error? {
        HttpToGmailAdaptor adaptor = check new (s);
        self.httpService = new HttpService(adaptor, self.gmailConfig, self.startHistoryId, self.subscriptionResource);
        check self.watchMailbox();
        check self.httpListener.attach(<HttpService>self.httpService, name);
        Job job = new (self);
        check job.scheduleNextWatchRenewal();
    }

    public isolated function detach(service object {} s) returns error? {
        return self.httpListener.detach(s);
    }

    public isolated function 'start() returns error? {
        return self.httpListener.'start();
    }

    public isolated function gracefulStop() returns @tainted error? {
        json deleteSubscription = check deletePubsubSubscription(self.pubSubClient, self.subscriptionResource);
        json deleteTopic = check deletePubsubTopic(self.pubSubClient, self.topicResource);
        var response = check stop(self.gmailHttpClient, self.userId);
        log:printInfo(WATCH_STOPPED + response.toString());
        return self.httpListener.gracefulStop();
    }

    public isolated function immediateStop() returns error? {
        return self.httpListener.immediateStop();
    }

    public isolated function watchMailbox() returns @tainted error? {
        WatchResponse response = check watch(self.gmailHttpClient, self.userId, self.requestBody);
        self.startHistoryId = response.historyId;
        log:printInfo(NEW_HISTORY_ID + self.startHistoryId);
        HttpService? httpService = self.httpService;
        if (httpService is HttpService) {
            httpService.setStartHistoryId(self.startHistoryId);
        }
    }
}

# Holds the parameters used to create a `Client`.
#
# + authConfig - Auth client configuration
# + secureSocketConfig - Secure socket configuration
@display {label: "Listener Connection Config"}
public type GmailListenerConfiguration record {
    @display {label: "Auth Config"}
    http:JwtIssuerConfig authConfig;
    @display {label: "SSL Config"}
    http:ClientSecureSocket secureSocketConfig?;
};
