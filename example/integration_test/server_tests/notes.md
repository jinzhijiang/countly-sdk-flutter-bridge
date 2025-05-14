Server tests that tries the scenarios of server responses

All automatic calls are disabled to validate internal request triggering.

## BM_200_timeoutDelay
Respond from the mock server with a timeout which will give timeout exception.
Our current timeout is 10 seconds, providing 10 would be timed out the requests

Flow:
- Call begin session
- wait for 30 seconds 
- validate that begin session request is still there

## BM_201A_backoffDelay
Respond from the mock server with a timeout which will trigger backoff mechanism and request are younger then 12 hours and 
there are requests less then %10 of max request queue

Config:
delay is 9 seconds

Flow:
- Call begin session, wait 2 secs
- Call update session, wait 2 secs
- Call end session
- Validate that queue have 2 requests and first one is orientation, second one is end session request

## BM_201B_backoffDelay_requests
Respond from the mock server with a timeout which will trigger backoff mechanism and request are younger then 12 hours but
there are requests greater then %10 of max request queue

Config:
delay is 9 seconds
max request queue size is 5

Flow:
- Call begin session, wait 2 secs
- Call update session, wait 2 secs
- Call end session
- Validate that request queue is empty

## BM_201C_backoffDelay_oldRequests
Respond from the mock server with a timeout which will trigger backoff mechanism and request are younger then 12 hours but
there are requests less then %10 of max request queue

Config:
delay is 9 seconds
queue has couple of requests that is older then 12 hours

Flow:
- Validate that request queue is empty
