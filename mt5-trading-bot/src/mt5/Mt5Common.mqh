#ifndef __MT5_COMMON_MQH__
#define __MT5_COMMON_MQH__

#property strict

#include <stderror.mqh>

namespace Mt5Common
{
   int NormalizeDelay(const int requested, const int minimum = 50)
   {
      return MathMax(minimum, requested);
   }

   bool EnsureConnection(const string component, const int maxAttempts, const int delayMs)
   {
      if(TerminalInfoInteger(TERMINAL_CONNECTED))
         return true;

      for(int attempt = 0; attempt < maxAttempts; attempt++)
      {
         PrintFormat("%s waiting for terminal connection (%d/%d)...", component, attempt + 1, maxAttempts);
         Sleep(delayMs);
         if(TerminalInfoInteger(TERMINAL_CONNECTED))
            return true;
      }

      PrintFormat("%s aborted: terminal disconnected.", component);
      return false;
   }

   void LogError(const string component, const string context, const int errorCode)
   {
      PrintFormat("%s %s failed. Error %d - %s", component, context, errorCode, ErrorDescription(errorCode));
   }
}

#endif // __MT5_COMMON_MQH__
