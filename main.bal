import ballerina/http;
import ballerina/lang.regexp;
import ballerina/log;
import ballerinax/googleapis.gmail;
import ballerinax/trigger.asgardeo;

configurable asgardeo:ListenerConfig config = ?;

configurable string gmailClientId = ?;
configurable string gmailClientSecret = ?;
configurable string gmailRefreshToken = ?;
configurable string recipientEmail = ?;

listener http:Listener httpListener = new (8090);
listener asgardeo:Listener webhookListener = new (config, httpListener);

service asgardeo:RegistrationService on webhookListener {

    remote function onAddUser(asgardeo:AddUserEvent event) returns error? {

        log:printInfo(event.toJsonString());
        asgardeo:GenericUserData? userData = event.eventData;
        error? err = sendMail(<map<json>>userData.toJson());
        if (err is error) {
            log:printInfo(err.message());
        }
        return;
    }

    remote function onConfirmSelfSignup(asgardeo:GenericEvent event) returns error? {
        return;
    }

    remote function onAcceptUserInvite(asgardeo:GenericEvent event) returns error? {
        return;
    }

}

service /ignore on httpListener {
}

function sendMail(map<json> userData) returns error? {

    string tableTemplate = check generateTable(userData);
    string emailTemplate = "<!DOCTYPE html><html><head><style>table { border-collapse: collapse; border: 1px solid black; width: 80%; margin: 20px auto; } th, td { border: 1px solid black; padding: 5px; } table table { width: 100%; margin: 10px auto; } table table th, table table td { border: 1px solid #ddd; } </style></head><body><h1>New User Sign Up!</h1><div>A new user has registered on fhirtools.io.<br /><br /><b>User Information</b></div>" + tableTemplate + "</body></html>";

    gmail:Client gmail = check new ({
        auth: {
            refreshToken: gmailRefreshToken,
            clientId: gmailClientId,
            clientSecret: gmailClientSecret
        }
    });

    gmail:MessageRequest message = {
        to: [recipientEmail],
        subject: "[fhirtools.io] New User Sign Up",
        bodyInHtml: emailTemplate
    };

    gmail:Message sendResult = check gmail->/users/me/messages/send.post(message);
    log:printInfo("Email sent. Message ID: " + sendResult.id);
}

function generateTable(map<json> userData) returns string|error {
    
    string htmlTable = "<table style='margin-left: 0; margin-right: auto'><thead><tr><th>Field</th><th>Value</th></tr></thead><tbody>";
    map<json> claims = check userData.claims.ensureType();
    foreach string val in userData.keys() {
        if val == "claims" {
            htmlTable += "<tr><td>claims</td><td><table><thead><tr><th>Claim</th><th>Value</th></tr></thead><tbody>";
            string[] claimSplit;
            foreach string claim in claims.keys() {
                claimSplit = regexp:split(re `/`, claim);
                htmlTable += string `<tr><td>${claimSplit[claimSplit.length() - 1]}</td><td>${claims[claim].toString()}</td></tr>`;
            }
            htmlTable += "</tbody></table></td></tr></tbody></table>";
            return htmlTable;
        }
        htmlTable += string `<tr><td>${val}</td><td>${userData[val].toString()}</td></tr>`;
    }
    htmlTable += "</tbody></table>";
    return htmlTable;
}

