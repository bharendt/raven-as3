/**
 * This file is part of Raven AS3 client.
 *
 * (c) Alexis Couronne
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

package scopart.raven
{
	import com.adobe.serialization.json.JSON;

	import flash.utils.ByteArray;

	/**
	 * @author Alexis Couronne
	 */
	public class RavenClient
	{
		private var _config : RavenConfig;
		private var _sender : RavenMessageSender;
		private var _lastID : String;
		
		public static const DEBUG : uint = 10;
		public static const INFO : uint = 20;
		public static const WARN : uint = 30;
		public static const ERROR : uint = 40;
		public static const FATAL : uint = 50;
		
		public static const VERSION : String = '0.1';
		public static const NAME : String = 'raven-as3/' + VERSION;
		
		/**
		 * User ID that can be sent to sentry, if availabe 
		 **/
		public var userID:int = -1;

		/**
		 * User name that can be sent to sentry, if available and
		 * if userID != -1 
		 **/
		public var userName:String = null;

		/**
		 * E-Mail address of the user, that can be sent to sentry, 
		 * if available and if userID != -1 
		 **/
		public var userEMail:String = null;
		
		/**
		 * Additional information that will be sent in the 'Environment' section
		 * of the HTTP Request information that is sent in addition to errors.
		 **/
		public var additionalInfo:Object = null;

		public function RavenClient(sentryDSN : String)
		{
			if (sentryDSN == null || sentryDSN.length == 0)
			{
				throw new ArgumentError("You must provide a DSN to RavenClient");
			}
			_config = new RavenConfig(sentryDSN);
			_sender = new RavenMessageSender(_config);
		}

		/**
		 * Log a message to sentry
		 */
		public function captureMessage(message : String, logger : String = 'root', level : int = ERROR, culprit : String = null) : String
		{
			var now : Date = new Date();
			var messageBody : String = buildMessage(message, RavenUtils.formatTimestamp(now), logger, level, culprit, null);
			_sender.send(messageBody, now.time);
			return _lastID;
		}

		/**
		 * Log an exception to Sentry
		 */
		public function captureException(error : Error, message : String = null, logger : String = 'root', level : int = ERROR, culprit : String = null) : String
		{
			var now : Date = new Date();
			var messageBody : String = buildMessage(message || error.message, RavenUtils.formatTimestamp(now), logger, level, culprit, error);
			_sender.send(messageBody, now.time);
			return _lastID;
		}

		/**
		 * @private
		 */
		private function buildMessage(message : String, timeStamp : String, logger : String, level : int, culprit : String, error : Error) : String
		{
			var json : String = buildJSON(message, timeStamp, logger, level, culprit, error);
			var byteArray : ByteArray = new ByteArray();
			byteArray.writeMultiByte(json, 'iso-8859-1');
			return RavenBase64.encode(byteArray);
		}

		/**
		 * @private
		 */
		private function buildJSON(message : String, timeStamp : String, logger : String, level : int, culprit : String, error : Error) : String
		{
			_lastID = RavenUtils.uuid4();
			var object : Object = new Object();
			object['message'] = message;
			object['event_id'] = _lastID;
			if (error == null)
			{
				object['culprit'] = culprit;
			}
			else
			{
				object['culprit'] = determineCulprit(error);
				object['sentry.interfaces.Exception'] = buildException(error);
				object['sentry.interfaces.Stacktrace'] = buildStacktrace(error);
				object['sentry.interfaces.Http'] = buildHttpInfo();
			}
			
			if(this.userID != -1) {
				object['sentry.interfaces.User'] = buildUserInfo();
			}
			
			object['timestamp'] = timeStamp;
			object['project'] = _config.projectID;
			object['level'] = level;
			object['logger'] = logger;
			object['server_name'] = RavenUtils.getHostname();
			return JSON.encode(object);
		}
		
		private function buildUserInfo():Object {
			var userInfo:Object = {
				id: this.userID
			};
			if(this.userName) {
				userInfo['username'] = this.userName;
			}
			if(this.userEMail) {
				userInfo['email'] = this.userEMail;
			}
			return userInfo;
		}
		
		private function buildHttpInfo():Object {
			return {
				url: RavenUtils.getClientURL(),
				query_string: "Client Information",
				env: RavenUtils.addClientInformation(this.additionalInfo || new Object()),
				headers: RavenUtils.getUserAgentHeaders()
			}
		}

		/**
		 * @private
		 */
		private function buildException(error : Error) : Object
		{
			var object : Object = new Object();
			object['type'] = RavenUtils.getClassName(error);
			object['value'] = error.message;
			object['module'] = RavenUtils.getModuleName(error);
			return object;
		}

		/**
		 * @private
		 */
		private function buildStacktrace(error : Error) : Object
		{
			var result : Object = new Object();
			result['frames'] = RavenUtils.parseStackTrace(error);
			return result;
		}

		/**
		 * @private
		 */
		private function determineCulprit(error : Error) : String
		{
			return error.getStackTrace() != null ? error.getStackTrace().split('\n')[0] : error.message;
		}
	}
}
