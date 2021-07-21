// Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

//API urls
# Holds the value for URL of gmail.
public const string BASE_URL = "https://www.googleapis.com/gmail";
# Holds the value for URL of refresh token end point.
public const string REFRESH_URL = "https://oauth2.googleapis.com/token";
# Holds the value for oauth scheme.
const string OAUTH = "oauth";

# Holds the value for user resource path.
const string USER_RESOURCE = "/v1/users/";
# Holds the value for messages resource path.
public const string MESSAGE_RESOURCE = "/messages";
# Holds the value for send messages resource.
const string MESSAGE_SEND_RESOURCE = "/messages/send";
# Holds the value for attachments resource path.
const string ATTACHMENT_RESOURCE = "/attachments/";
# Holds the value for threads resoure path.
public const string THREAD_RESOURCE = "/threads";
# Holds the value for profile resource path.
const string PROFILE_RESOURCE = "/profile";
# Holds the value for label resource path.
const string LABEL_RESOURCE = "/labels";
# Holds the value for modify resource action.
const string MODIFY_RESOURCE = "/modify";
# Holds the value for history resource path.
const string HISTORY_RESOURCE = "/history";
# Holds the value for drafts resource path.
const string DRAFT_RESOURCE = "/drafts";
# Holds the value for send draft resource.
const string DRAFT_SEND_RESOURCE = "/drafts/send";

# Holds the value for empty string.
const string EMPTY_STRING = "";
# Holds the value for new line string.
const string NEW_LINE = "\n";
# Holds the value for ";" string.
const string WHITE_SPACE = " ";
# Holds the value for ":" string.
const string COLON_SYMBOL = ":";
# Holds the value for "-" string.
const string DASH_SYMBOL = "-";
# Holds the value for "/" string.
const string FORWARD_SLASH_SYMBOL = "/";
# Holds the value for "+" string.
const string PLUS_SYMBOL = "+";
# Holds the value for "_" string.
const string UNDERSCORE_SYMBOL = "_";
# Holds the value for ";" string.
const string SEMICOLON_SYMBOL = ";";
# Holds the value for "=" string.
const string EQUAL_SYMBOL = "=";
# Holds the value for "\"" string.
const string APOSTROPHE_SYMBOL = "\"";
# Holds the value for "?" string.
const string QUESTION_MARK_SYMBOL = "?";
# Holds the value for "&" string.
const string AMPERSAND_SYMBOL = "&";
# Holds the value for ">" string.
const string GREATER_THAN_SYMBOL = ">";
# Holds the value for "<" string.
const string LESS_THAN_SYMBOL = "<";
# Holds the value for "*" string.
const string STAR_SYMBOL = "*";

# Holds the value for optional parameter name 'includeSpamTrash'.
const string INCLUDE_SPAMTRASH = "includeSpamTrash";
# Holds the value for optional parameter name 'labelIds'.
const string LABEL_IDS = "labelIds";
# Holds the value for optional parameter name 'maxResults'.
const string MAX_RESULTS = "maxResults";
# Holds the value fo optional parameter name 'pageToken'.
const string PAGE_TOKEN = "pageToken";
# Holds the value for optional parameter name 'q'.
const string QUERY = "q";
# Holds the value for optional parameter name 'format'.
public const string FORMAT = "format";
# Holds the value for optional parameter name 'metadataHeaders'.
public const string METADATA_HEADERS = "metadataHeaders";
# Holds the value for 'historyTypes'.
const string HISTORY_TYPES = "historyTypes";
# Holds the value for 'labelId'.
const string LABEL_ID = "labelId";
# Holds the value for 'startHistoryId'.
const string START_HISTORY_ID = "startHistoryId";

# Holds value for Content-Type.
const string CONTENT_TYPE = "Content-Type";
# Holds value for Content-Disposition.
const string CONTENT_DISPOSITION = "Content-Disposition";
# Holds value for Content-Transfer-Encoding.
const string CONTENT_TRANSFER_ENCODING = "Content-Transfer-Encoding";
# Holds value for Content-ID.
const string CONTENT_ID = "Content-ID";
# Holds value for boundary.
const string BOUNDARY = "boundary";
# Holds value for boundaryString.
const string BOUNDARY_STRING = "boundaryString";
# Holds value for boundaryString1.
const string BOUNDARY_STRING_1 = "boundaryString1";
# Holds value for boundaryString2.
const string BOUNDARY_STRING_2 = "boundaryString2";

# Holds value for multipart/*.
const string MULTIPART_ANY = "multipart/*";
# Holds value for text/*.
const string TEXT_ANY = "text/*";
# Holds value for image/*.
const string IMAGE_ANY = "image/*";
# Holds value for charset.
const string CHARSET = "charset";
# Holds value for base64.
const string BASE_64 = "base64";
# Holds value for inline.
const string INLINE = "inline";
# Holds value for attachment.
const string ATTACHMENT = "attachment";
# Holds value for filename.
const string FILE_NAME = "filename";
# Holds value for name.
const string NAME = "name";
# Holds value for inline image content id prefix.
const string INLINE_IMAGE_CONTENT_ID_PREFIX = "image-";
# Holds value for UTF-8.
const string UTF_8 = "UTF-8";
# Holds default value for bytes chunk to read from a byte channel.
const int BYTES_CHUNK = 100000000;
# Holds the value for trash.
const string TRASH = "trash";
# Holds the value for untrash.
const string UNTRASH = "untrash";
# Holds the value for error.
const string ERROR = "error";
# Holds the value for domain.
const string DOMAIN = "domain";
# Holds the value for reason.
const string REASON = "reason";
# Holds the value for message.
const string MESSAGE = "message";
# Holds the value for locationType.
const string LOCATION_TYPE = "locationType";
# Holds the value for location.
const string LOCATION = "location";
# Holds the value for status code.
const string STATUS_CODE = "status code";

# Holds name for header To.
const string TO = "To";
# Holds name for header From.
const string FROM = "From";
# Holds name for header Cc.
const string CC = "Cc";
# Holds name for header Bcc.
const string BCC = "Bcc";
# Holds name for header Subject.
const string SUBJECT = "Subject";
# Holds name for header Date.
const string DATE = "Date";
# Holds name for id.
const string ID = "id";
# Holds name for threadId.
const string THREAD_ID = "threadId";

# Holds string for Gmail message/thread response format **full**.
public const string FORMAT_FULL = "full";
# Holds string for Gmail message/thread response format **metadata**.
public const string FORMAT_METADATA = "metadata";
# Holds string for Gmail message/thread response format **minimal**.
public const string FORMAT_MINIMAL = "minimal";
# Holds string for Gmail message/thread response format **raw**.
public const string FORMAT_RAW = "raw";

# Holds value for message type **text/plain**.
public const string TEXT_PLAIN = "text/plain";
# Holds value for message type **text/html**.
public const string TEXT_HTML = "text/html";
# Holds the value "me". Used as current authenticated userId.
const string ME = "me";

// Error Codes
const string GMAIL_ERROR_CODE = "(ballerinax/googleapis.gmail)GmailError";
const string ERR_MESSAGE_LIST = "Error occurred while constructing MessageListPage record.";
const string ERR_THREAD_LIST = "Error occurred while constructing ThreadListPage record.";
const string ERR_DRAFT_LIST = "Error occurred while constructing DraftListPage record.";
const string ERR_MAILBOX_HISTORY_LIST = "Error occurred while constructing MailboxHistoryPage record.";
