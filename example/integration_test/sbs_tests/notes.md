SDK Behavior Settings tests

And where to check values, which is affected:
from_server = FS
storage = S
provided = P
dev_provided = DP

200X tests are feature validation tests
where
A = SDK internal limits + Content Zone + Content Zone Interval + Refresh Content Zone + Backoff Mechanism Enabled
B = Tracking + Server Config Update Interval - will not affect SC request
C = Networking + Consent + Request Queue + Session Update Interval + Drop old request - will not affect SC request
D = Session Tracking + Custom Event Tracking + Event Queue + View Tracking + Location Tracking + Crash Tracking + Backoff Configs

Tests

- A
Call all features
Provide SBS from server {'lkl': 5, 'lvs': 5, 'lsv': 5, 'lbc': 5, 'ltlpt': 5, 'ltl': 5, 'rcz': false, 'cz': true, 'czi': 16, 'bom': false}
Change all SDK internal limits and validate that all are applied
Trigger two requests that their response duration is above 10 seconds
Validate that:
- content zone is called after init
- provided zone timer interval is not default one and 16
- refresh content zone call is disabled
- backoff mechanism is disabled and two requests are passed
- validate the constraints for the backoff before sending requests

- B
Call all features
Provide SBS from server {'tracking': false, 'scui': 1}
Validate that:
- No requests exist in the sent requestArray in mock server
- RQ is empty
- Only SBS requests are existing
- Validate that next SBS fetch called in 1 hours

- C
Call all features
Provide SBS from server {'networking': false, 'cr': true, 'rqs': 5, 'sui': 10, 'dort': 1}
Store couple of requests before starting the SDK and show that they are deleted by drop request age
Validate that:
- No requests exist in the sent requestArray in mock server
- RQ contains items
- Features that requires consent is not called and did not recorded things in RQ
- every 10 seconds session triggered

- D
Call all features
Provide SBS from server {'st': false, 'cet': false, 'vt': false, 'eqs': 5, 'lt': false, 'crt': false, 'bom_at': 5, 'bom_d': 30, 'bom_rqp': 0.01, 'bom_ra': 1}
Validate that:
- Session, custom events, location, crashes, views are not recorded
- Internal events are recorded and clipped by EQ limit
- Views are not affected by custom event tracking
- Backoff mechanism configs are applied

---------------------------------------------------------------------------------------------------------------------------------

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

tests are:
- 201A_DP_FS
- 201B_DP_P
- 201C_DP_P_FS
- 201D_DP_S_FS
- 201E_DP_S_P_FS

Notes iOS:
In the base test iOS required more time then Android at the end
Because there is a probability for iOS to duplicate requests, checking request counts were not good
getAvaliableFeedbackWidgets= if no consent it broken iOS
