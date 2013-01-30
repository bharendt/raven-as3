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

		public static function getHostname() : String
		{
			return "test";
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
				abs_path: ""
			};
			var matches:Array = frame.match(/(\s*at\s*)?([^\(]*[^\)]*\))[^\[]*(\[([^\]]*)])?/);
			var lineNumber:int = NaN;
			if(matches && matches.length >= 3 && matches[2] is String) {
				stackFrame['function'] = matches[2];
			} else {
				stackFrame['function'] = frame;
			}
			if(matches && matches.length >= 5 && matches[4] is String) {
				stackFrame['filename'] = matches[4]; 
				matches = String(matches[4]).match(/(.*):(\d+)$/);
				if(matches && matches.length >= 2 && matches[1] is String) {
					stackFrame['filename'] = matches[1]; 
					if(matches && matches.length >= 3 && matches[2] is String && !isNaN(lineNumber = parseInt(matches[2]))) {
						stackFrame['lineno'] = lineNumber; 
					}
				}
			}
			return stackFrame;
		}

		public static function parseStackTrace(error : Error) : Array
		{
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
				info['flashVersion'] = Capabilities.version;
				info['screenResolutionX'] = Capabilities.screenResolutionX;
				info['screenResolutionY'] = Capabilities.screenResolutionY;
				info['hasAccessibility'] = Capabilities.hasAccessibility;
				info['hasAudio'] = Capabilities.hasAudio;
				info['hasAudioEncoder'] = Capabilities.hasAudioEncoder;
				info['hasEmbeddedVideo'] = Capabilities.hasEmbeddedVideo;
				info['hasIME'] = Capabilities.hasIME;
				info['hasMP3'] = Capabilities.hasMP3;
				info['hasPrinting'] = Capabilities.hasPrinting;
				info['hasScreenBroadcast'] = Capabilities.hasScreenBroadcast;
				info['hasScreenPlayback'] = Capabilities.hasScreenPlayback;
				info['hasStreamingAudio'] = Capabilities.hasStreamingAudio;
				info['hasStreamingVideo'] = Capabilities.hasStreamingVideo;
				info['hasTLS'] = Capabilities.hasTLS;
				info['hasVideoEncoder'] = Capabilities.hasVideoEncoder;
				info['touchscreenType'] = Capabilities.touchscreenType;
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
