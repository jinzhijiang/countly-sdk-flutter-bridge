SDK Behavior Settings tests

And where to check values, which is affected:
from_server
storage
provided
dev_provided

Order validation
200X tests are feature validation tests
where
A = SDK internal limits
B = Tracking - will not affect SC request
C = Networking - will not affect SC request
D = Request Queue + Event Queue + Session Update Interval
E = Session Tracking + Crash Tracking + Location Tracking
F = Custom Event Tracking + View Tracking
G = Consent + Drop old request + Server config update interval
H = Content Zone + Content Zone Interval + Refresh Content Zone
I = Backoff

Tests

- A variants: from_server, provided, dev_provided, storage
Change all SDK internal limits, respond them from the ${variant} and validate that all truncable things cool
at the end validate all queues are empty

- B
Provide SBS through config, that it disables tracking
call all functions, validate server request list only contains server config and queues are empty

Stop the SDK, clear stored SBS, provide SDK config through config again with tracking disabled
but let server respond tracking enabled, call all functions, validate queues are empty, all requests are sent

This also validates server response sbs > provided sbs

- C
Provide SBS through config, that it disables networking
call all functions, validate server request list only contains server config and queues are containing all features' requests

Stop the SDK, clear stored SBS, provide SDK config through config again with networking disabled
but let server respond networking enabled, call all functions, validate queues are empty, all requests are sent

This also validates server response sbs > provided sbs

- D variants: from_server, provided, dev_provided, storage
Provide SBS through ${variant}, validate that:
Request queue is clipped with new limit
Event queue is clipped with new limit
Session update times are same as new limit

- E variants: from_server, provided, storage
Call all features, respond from the ${variant} with disabling features
Validate that session and crash are not existing in the server request list
And location is existing as location disabled request
Validate RQ is not containing any crash and session requests

To validate location works with/without session
stop the SDK, re init it with enabling session and validate begin_session contains location which is empty strinh

- F
Call all functions validate that all called views and custom events are no containig in the EQ, RQ and server request list

Stop the SDK, re init with views enabled, now validate views are existing in all the queues because they must not be affected
with custom event tracking

- G variants: from_server, provided, dev_provided, storage
Add some old requests to the storage
Validate RQ containing old requests
Call all functions, validate that all consent required features are disabled and do not generate any request.
And validate that RQ is not containing old requests
???Somehow give server config update time very low and validate SC is triggered again

- H variants: from_server, provided, dev_provided, storage
Call all functions, validate that content zone is entered automatically in the init
And validate that refresh content zone is not called
And validate content zone called again after configured time

- I variants: from_server, provided, dev_provided, storage
call all functions with a delay where backoff would be triggered with changed parameters.
First do not disable backoff, and try other parameters

stop the sdk and re init it with disabling backoff. Now try that backoff mechanism is not triggered.

201X tests order validation
where
- A
configure all configurables via CountlyConfig validate that all set
then trigger server fetch and validate that server values changed the dev_provided configs

- B
configure all configurables and provide SBS via CountlyConfig.
Validate that all dev_provided is overridden by provided.

- C
configure all configurables, and provide SBS via CountlyConfig
and respond from the server, validate that server values are precedence.

- D
configure all configurables, store SBS before initializing, validate that stored values have the precedence
trigger server fetch and validate that all values from_server

- E
configure all configurables, store SBS before initializing, provide SBS via CountlyConfig, validate that provided values have the precedence
trigger server fetch and validate that all values from_server
