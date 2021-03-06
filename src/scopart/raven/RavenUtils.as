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
	import com.adobe.crypto.HMAC;
	import com.adobe.crypto.SHA1;
	
	import flash.external.ExternalInterface;
	import flash.system.Capabilities;
	import flash.utils.getQualifiedClassName;

	/**
	 * @author Alexis Couronne
	 */
	public class RavenUtils
	{
		/**
		 * Generate an uuid4 value
		 */
		public static function uuid4() : String
		{
			var result : String = '';
			result += randInt(0, 0xffff).toString(16).substr(0, 4);
			result += randInt(0, 0xffff).toString(16).substr(0, 4);

			result += randInt(0, 0xffff).toString(16).substr(0, 4);

			result += (randInt(0, 0x0fff) | 0x4000).toString(16).substr(0, 4);

			result += (randInt(0, 0x3fff) | 0x8000).toString(16).substr(0, 4);

			result += randInt(0, 0xffff).toString(16).substr(0, 4);
			result += randInt(0, 0xffff).toString(16).substr(0, 4);
			result += randInt(0, 0xffff).toString(16).substr(0, 4);

			return result;
		}

		/**
		 * Generate message signature
		 */
		public static function getSignature(messageBody : String, timestamp : Number, secretKey : String) : String
		{
			return HMAC.hash(secretKey, timestamp + ' ' + messageBody, SHA1);
		}

		/**
		 * Generate a randon int between min and max passed-in values.
		 */
		public static function randInt(min : int, max : int) : int
		{
			return Math.round(min + Math.random() * (max - min));
		}
		
		/**
		 * Parses a single line of a stace trace and returns a stack frame object
		 * containing in any case a 'function' property and optional
		 * 'filename' and 'lineno' properties if they were available in the 
		 * strack trace line. 
		 */
		public static function parseStackFrame(frame:String):Object {
			var stackFrame:Object = {
				in_app: true,
				abs_path: "",
				module: ""
			};
			var matches:Array = frame.match(/(\s*at\s*)?([^\(]*[^\)]*\))[^\[]*(\[([^\]]*)])?/);
			var lineNumber:int = NaN;
			var functionName:String;
			var fileName:String;
			if(matches && matches.length >= 3 && matches[2] is String) {
				stackFrame['function'] = functionName = matches[2];
			} else {
				stackFrame['function'] = functionName = frame;
			}
			if(matches && matches.length >= 5 && matches[4] is String) {
				stackFrame['filename'] = fileName = matches[4]; 
				matches = String(matches[4]).match(/(.*):(\d+)$/);
				if(matches && matches.length >= 2 && matches[1] is String) {
					stackFrame['filename'] = fileName = matches[1]; 
					if(matches && matches.length >= 3 && matches[2] is String && !isNaN(lineNumber = parseInt(matches[2]))) {
						stackFrame['lineno'] = lineNumber; 
					}
				}
				// split path into file name and path name
				if(fileName && fileName.length > 0) {
					if(fileName.search(/[^\\]\//) != -1 && fileName.search(/[^\\]\\[^ &&^\\]/) == -1) {
						matches = fileName.match(/^(.*[^\\])\/([^\/]+)$/); // linux path
					} else if(fileName.search(/[^\\]\//) == -1 && fileName.search(/[^\\]\\[^ &&^\\]/) != -1) {
						matches = fileName.match(/^(.*[^\\])\\([^ &&^\\][^\\]+)$/) // windows path
					} else {
						matches = null;
					}
					if(matches && matches.length == 3) {
						stackFrame['abs_path'] = matches[1];
						stackFrame['filename'] = matches[2];
					}
				}
			}
			// split function name into module and function name
			if(functionName) {
				matches = functionName.match(/^(\w+[^\s]+::[^\/]+)\/(.*)$/);
				if(matches && matches.length == 3) {
					stackFrame['module'] = matches[1];
					stackFrame['function'] = matches[2];
				}
			}
			return stackFrame;
		}

		public static function parseStackTrace(error : Error) : Array
		{
			if(error.getStackTrace() == null) {
				return [{
					in_app: true,
					abs_path: "No Stacktrace available for Error: " + error.message + "."
				}]
			}
			var result : Array = new Array();
			var elements : Array = error.getStackTrace().split('\n');
			for (var i : int = 1 ; i < elements.length ; i++) {
				result.push(parseStackFrame(elements[i]));
			}
			return result.reverse();
		}

		public static function getClassName(object : Object) : String
		{
			var fullClassName : String = getQualifiedClassName(object);
			var splittedClassName : Array = fullClassName.split('::');
			return splittedClassName.length > 1 ? splittedClassName[1] : fullClassName;
		}

		public static function getModuleName(object : Object) : String
		{
			var fullClassName : String = getQualifiedClassName(object);
			var splittedClassName : Array = fullClassName.split('::');
			return splittedClassName[0];
		}
		
		public static function formatTimestamp(date : Date) : String
		{
			var result : String = '';
			var month : int = date.monthUTC + 1;
			
			result += date.fullYearUTC + '-';
			result += month < 10 ? ('0' + month + '-') : (month + '-');
			result += date.dateUTC + 'T';
			result += date.hoursUTC + ':';
			result += date.minutesUTC + ':';
			result += date.secondsUTC;
			return result;
		}
		
		/**
		 * Adds flash client information to the object. This information
		 * will be sent to the sentry server as additional information
		 * when errors are sent. 
		 **/
		public static function addClientInformation(info:Object):Object {
			try {
				info['flashVersion'] = 'version' in Capabilities ? Capabilities['version'] : 'unknown';
				var capabilities:Array = ['screenResolutionX', 'screenResolutionY', 'hasAccessibility', 'hasAudio', 'hasAudioEncoder', 'hasEmbeddedVideo', 'hasIME', 'hasMP3', 'hasPrinting', 'hasScreenBroadcast', 'hasScreenPlayback', 'hasStreamingAudio', 'hasStreamingVideo', 'hasTLS', 'hasVideoEncoder', 'touchscreenType']
				for each(var capability:String in capabilities) {
					if(capability in Capabilities) {
						info[capability] = Capabilities[capability];
					}
				}
			}catch(error:*) {}
			
			return info;
		}
		
		/**
		 * Gets the url from the clients browser
		 **/
		public static function getClientURL():String {
			try {
				return ExternalInterface.call("window.location.href.toString") || "";
			}catch(error:*) {}
			return "";
		}
		
		/**
		 * Gets a http header object containing the 'User-Agent' key with the current value.
		 * This is used as additional information when errors are sent to the sentry server
		 **/
		public static function getUserAgentHeaders():Object {
			try {
				return {'User-Agent': ExternalInterface.call("window.navigator.userAgent.toString") || ""};
			}catch(error:*) {}
			return {};
		}
		
	}
}
