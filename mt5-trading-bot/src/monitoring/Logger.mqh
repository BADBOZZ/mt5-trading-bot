#ifndef __LOGGER_MONITORING_MQH__
#define __LOGGER_MONITORING_MQH__

#define LOGGER_DEFAULT_FILE      "logs/mt5-bot.log"
#define LOGGER_ROTATE_EXTENSION  ".bak"

enum LogLevel
  {
   LOG_LEVEL_TRACE = 0,
   LOG_LEVEL_DEBUG = 1,
   LOG_LEVEL_INFO  = 2,
   LOG_LEVEL_WARN  = 3,
   LOG_LEVEL_ERROR = 4,
   LOG_LEVEL_FATAL = 5
  };

string LoggerNormalizePath(const string value)
  {
   string normalized = value;
   StringReplace(normalized, "\\", "/");
   return normalized;
  }

void LoggerEnsureDirectories(const string filePath)
  {
   string normalized = LoggerNormalizePath(filePath);
   string parts[];
   int count = StringSplit(normalized, "/", parts);
   if(count <= 1)
      return;

   string path = "";
   for(int i = 0; i < count - 1; i++)
     {
      if(StringLen(parts[i]) == 0)
         continue;
      if(StringLen(path) > 0)
         path += "/";
      path += parts[i];
      FolderCreate(path);
     }
  }

class Logger
  {
private:
   string   m_filePath;
   LogLevel m_minLevel;
   bool     m_consoleEcho;
   bool     m_includeTimestamp;
   int      m_maxFileSize;
   bool     m_ready;

public:
            Logger(void);
   bool     Configure(const string fileName = LOGGER_DEFAULT_FILE,
                      const LogLevel level   = LOG_LEVEL_INFO,
                      const bool consoleEcho = true,
                      const bool timestamp   = true,
                      const int maxBytes     = 1048576);
   void     SetLevel(const LogLevel level);
   void     EnableConsoleEcho(const bool enabled);
   void     EnableTimestamp(const bool enabled);
   void     SetMaxFileSizeBytes(const int bytes);
   void     Log(const LogLevel level, const string message);
   void     Trace(const string message);
   void     Debug(const string message);
   void     Info(const string message);
   void     Warn(const string message);
   void     Error(const string message);
   void     Fatal(const string message);

private:
   bool     EnsureReady(void);
   void     LogInternal(const LogLevel level, const string message);
   void     RotateIfNeeded(void);
   void     WriteLine(const string text);
   string   FormatLine(const LogLevel level, const string message) const;
   string   LevelLabel(const LogLevel level) const;
  };

Logger::Logger(void)
  {
   m_filePath         = LOGGER_DEFAULT_FILE;
   m_minLevel         = LOG_LEVEL_INFO;
   m_consoleEcho      = true;
   m_includeTimestamp = true;
   m_maxFileSize      = 1048576;
   m_ready            = false;
  }

bool Logger::Configure(const string fileName,
                       const LogLevel level,
                       const bool consoleEcho,
                       const bool timestamp,
                       const int maxBytes)
  {
   m_filePath         = LoggerNormalizePath(StringLen(fileName) == 0 ? LOGGER_DEFAULT_FILE : fileName);
   m_minLevel         = level;
   m_consoleEcho      = consoleEcho;
   m_includeTimestamp = timestamp;
   m_maxFileSize      = maxBytes;

   LoggerEnsureDirectories(m_filePath);
   m_ready = true;
   return true;
  }

void Logger::SetLevel(const LogLevel level)
  {
   m_minLevel = level;
  }

void Logger::EnableConsoleEcho(const bool enabled)
  {
   m_consoleEcho = enabled;
  }

void Logger::EnableTimestamp(const bool enabled)
  {
   m_includeTimestamp = enabled;
  }

void Logger::SetMaxFileSizeBytes(const int bytes)
  {
   if(bytes <= 0)
      return;
   m_maxFileSize = bytes;
  }

bool Logger::EnsureReady(void)
  {
   if(m_ready)
      return true;

   LoggerEnsureDirectories(m_filePath);
   m_ready = true;
   return true;
  }

void Logger::Log(const LogLevel level, const string message)
  {
   LogInternal(level, message);
  }

void Logger::Trace(const string message)
  {
   LogInternal(LOG_LEVEL_TRACE, message);
  }

void Logger::Debug(const string message)
  {
   LogInternal(LOG_LEVEL_DEBUG, message);
  }

void Logger::Info(const string message)
  {
   LogInternal(LOG_LEVEL_INFO, message);
  }

void Logger::Warn(const string message)
  {
   LogInternal(LOG_LEVEL_WARN, message);
  }

void Logger::Error(const string message)
  {
   LogInternal(LOG_LEVEL_ERROR, message);
  }

void Logger::Fatal(const string message)
  {
   LogInternal(LOG_LEVEL_FATAL, message);
  }

void Logger::LogInternal(const LogLevel level, const string message)
  {
   if(level < m_minLevel)
      return;

   if(!EnsureReady())
      return;

   string line = FormatLine(level, message);
   RotateIfNeeded();
   WriteLine(line);

   if(m_consoleEcho)
      Print(line);
  }

void Logger::RotateIfNeeded(void)
  {
   if(m_maxFileSize <= 0)
      return;

   if(!FileIsExist(m_filePath))
      return;

   int handle = FileOpen(m_filePath, FILE_READ | FILE_BIN);
   if(handle == INVALID_HANDLE)
      return;

   int size = (int)FileSize(handle);
   FileClose(handle);

   if(size < m_maxFileSize)
      return;

   string backup = m_filePath + LOGGER_ROTATE_EXTENSION;
   FileDelete(backup);
   if(!FileCopy(m_filePath, backup, FILE_COMMON))
      PrintFormat("Logger: unable to rotate file %s to %s (err=%d)", m_filePath, backup, GetLastError());
   FileDelete(m_filePath);
  }

void Logger::WriteLine(const string text)
  {
   int handle = FileOpen(m_filePath, FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("Logger: failed opening file %s (err=%d)", m_filePath, GetLastError());
      return;
     }

   FileSeek(handle, 0, SEEK_END);
   FileWriteString(handle, text);
   FileWriteString(handle, "\r\n");
   FileFlush(handle);
   FileClose(handle);
  }

string Logger::FormatLine(const LogLevel level, const string message) const
  {
   string timestamp = "";
   if(m_includeTimestamp)
      timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + " ";

   return timestamp + "[" + LevelLabel(level) + "] " + message;
  }

string Logger::LevelLabel(const LogLevel level) const
  {
   switch(level)
     {
      case LOG_LEVEL_TRACE: return "TRACE";
      case LOG_LEVEL_DEBUG: return "DEBUG";
      case LOG_LEVEL_INFO : return "INFO";
      case LOG_LEVEL_WARN : return "WARN";
      case LOG_LEVEL_ERROR: return "ERROR";
      case LOG_LEVEL_FATAL: return "FATAL";
      default:              return "LOG";
     }
  }

#endif // __LOGGER_MONITORING_MQH__
