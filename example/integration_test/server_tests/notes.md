Server tests that tries the scenarios of server responses

All automatic calls are disabled to validate internal request triggering.

## BM_200_timeoutDelay
Respond from the mock server with a timeout which will give timeout exception.
Our current timeout is 30 seconds, providing 30 would be timed out the requests

Flow:
- Call begin session
- wait for 90 seconds 
- validate that begin session request is still there

## BM_201A_backoffDelay
Respond from the mock server with a timeout which will trigger backoff mechanism and request are younger than 12 hours and 
there are requests less then %10 of max request queue

Config:
delay is 11 seconds

Flow:
- Call begin session, wait 2 secs
- Call update session, wait 2 secs
- Call end session
- Validate that queue have 2 requests and first one is orientation, second one is end session request

## BM_201B_backoffDelay_requests
Respond from the mock server with a timeout which will trigger backoff mechanism and request are younger than 12 hours but
there are requests greater then %10 of max request queue

Config:
delay is 11 seconds
max request queue size is 5

Flow:
- Call begin session, wait 2 secs
- Call update session, wait 2 secs
- Call end session
- Validate that request queue is empty

## BM_201C_backoffDelay_oldRequests
Respond from the mock server with a timeout which will trigger backoff mechanism and request are older than 12 hours but
there are requests less then %10 of max request queue

Config:
delay is 11 seconds
queue has couple of requests that is older then 12 hours

Flow:
- Call begin session for triggering RQ
- Validate that request queue is empty

## BM_201D_backoffDelay_both
Respond from the mock server with a timeout which will trigger backoff mechanism and request are older than 12 hours and
there are requests greater then %10 of max request queue

Config:
delay is 11 seconds
max request queue size is 5
queue has couple of requests that is older then 12 hours

Flow:
- Call begin session for triggering RQ
- Validate that request queue is empty

## BM_202_normalDelay
Respond from the mock server with a timeout which will not trigger backoff mechanism and request are older than 12 hours and
there are requests greater then %10 of max request queue

Config:
delay is 9 seconds
max request queue size is 10
queue has couple of requests that is older then 12 hours

Flow:
- Call begin session, wait 2 secs
- Call update session, wait 2 secs
- Call end session
- Validate that request queue is empty

## BM_203_doubleBackoffScenario
Server will respond with below delays in a row, we expect one backoff to be occured.

2, 9, 5, 7, 1, 0, 9, 9

Flow: