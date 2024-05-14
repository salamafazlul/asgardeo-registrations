import ballerina/email;
import ballerina/http;
import ballerina/log;
import ballerinax/trigger.asgardeo;

configurable asgardeo:ListenerConfig config = ?;
configurable string smtpUsername = ?;
configurable string smtpPassword = ?;
configurable string smtpHost = ?;
configurable string[] recipientEmails = ?;
configurable string senderEmail = ?;
configurable string emailSubject = ?;
configurable string emailTemplate = ?;

const string[] FIELDS = ["http://wso2.org/claims/emailaddress", "http://wso2.org/claims/created", "userName", "userId", "http://wso2.org/claims/photourl", "http://wso2.org/claims/givenname", "http://wso2.org/claims/lastname"];

listener http:Listener httpListener = new (8090);
listener asgardeo:Listener webhookListener = new (config, httpListener);

# A service for processing fhirtools.io user registrations and sending email notifications.
service asgardeo:RegistrationService on webhookListener {

    isolated remote function onAddUser(asgardeo:AddUserEvent event) returns error? {

        log:printDebug(event.toJsonString());
        log:printInfo("Adding new user");
        asgardeo:GenericUserData? userData = event.eventData;
        map<string>? claims = userData?.claims;

        if (claims["http://wso2.org/claims/emailaddress"].toString().includes("wso2.com")) {
            return;
        }

        error? err = sendMail(<map<json>>userData.toJson());
        if (err is error) {
            log:printError(err.message());
        }
        return;
    }

    isolated remote function onConfirmSelfSignup(asgardeo:GenericEvent event) returns error? {
        return;
    }

    isolated remote function onAcceptUserInvite(asgardeo:GenericEvent event) returns error? {
        return;
    }

}

service /ignore on httpListener {
}

# Sends an email notification containing user registration details.
#
# + userData - A JSON map containing user data retrieved from the Asgardeo event.
# + return - An error object if the email sending fails, otherwise null.
isolated function sendMail(map<json> userData) returns error? {

    string userDataTable = check generateUserDataTable(userData);
    string formattedEmailTemplate = string `${emailTemplate} ${userDataTable}`;

    email:SmtpConfiguration smtpConfig = {
        port: 587,
        security: "START_TLS_AUTO"
    };

    email:SmtpClient smtpClient = check new (smtpHost, smtpUsername, smtpPassword, smtpConfig);

    email:Message email = {
        to: recipientEmails,
        subject: emailSubject,
        'from: senderEmail,
        htmlBody: formattedEmailTemplate
    };

    check smtpClient->sendMessage(email);
    log:printInfo("Email sent");
}

# Generates an HTML table presenting user information in a formatted way.
#
# + userData - A JSON map containing user data retrieved from the Asgardeo event.
# + return - The generated HTML table representing user data.
isolated function generateUserDataTable(map<json> userData) returns string|error {

    string htmlTable = "<table style='margin-left: 0; margin-right: auto'><thead><tr><th>Field</th><th>Value</th></tr></thead><tbody>";
    string formattedKey;
    map<json> claims = check userData.claims.ensureType();

    foreach string key in FIELDS {
        formattedKey = key == "userName" ? "User Name" : key == "userId" ? "User ID" : "";
        if key.includes("claims") {
            if claims[key].toString() == "" {
                continue;
            }
            formattedKey = key.endsWith("created") ? "Signed Up Date" : key.endsWith("photourl") ? "Photo Url" : key.endsWith("emailaddress") ? "Email Address" : key.endsWith("lastname") ? "Last Name" : "Given Name";
            htmlTable += string `<tr><td>${formattedKey}</td><td>${claims[key].toString()}</td></tr>`;
            continue;
        }
        htmlTable += string `<tr><td>${formattedKey}</td><td>${userData[key].toString()}</td></tr>`;
    }
    htmlTable += "</tbody></table>";
    return htmlTable;
}

