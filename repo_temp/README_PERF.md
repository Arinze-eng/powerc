# Performance Optimization: CallGuardStore

Fixed lag in the call screening service by implementing an in-memory rule cache. 

- **Problem:** Frequent disk I/O and JSON parsing via SharedPreferences on every call event.
- **Fix:** Added  inside . 
- **Outcome:** Substantially reduced latency in  and  by serving rules from memory, with automatic cache invalidation on rule updates.
