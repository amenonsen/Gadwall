(function(c){function y(a){var g=a.data;a.isDefaultPrevented()||(a.preventDefault(),c(a.target).ajaxSubmit(g))}function u(a){var g=a.target,f=c(g);if(!f.is("[type=submit],[type=image]")){g=f.closest("[type=submit]");if(0===g.length)return;g=g[0]}var b=this;b.clk=g;"image"==g.type&&(void 0!==a.offsetX?(b.clk_x=a.offsetX,b.clk_y=a.offsetY):"function"==typeof c.fn.offset?(f=f.offset(),b.clk_x=a.pageX-f.left,b.clk_y=a.pageY-f.top):(b.clk_x=a.pageX-g.offsetLeft,b.clk_y=a.pageY-g.offsetTop));setTimeout(function(){b.clk=
b.clk_x=b.clk_y=null},100)}function q(){if(c.fn.ajaxSubmit.debug){var a="[jquery.form] "+Array.prototype.join.call(arguments,"");window.console&&window.console.log?window.console.log(a):window.opera&&window.opera.postError&&window.opera.postError(a)}}var z,B;z=void 0!==c("<input type='file'/>").get(0).files;B=void 0!==window.FormData;var D=!!c.fn.prop;c.fn.attr2=function(){if(!D)return this.attr.apply(this,arguments);var a=this.prop.apply(this,arguments);return a&&a.jquery||"string"===typeof a?a:
this.attr.apply(this,arguments)};c.fn.ajaxSubmit=function(a){function g(b){b=c.param(b,a.traditional).split("&");var g=b.length,d=[],f,m;for(f=0;f<g;f++)b[f]=b[f].replace(/\+/g," "),m=b[f].split("="),d.push([decodeURIComponent(m[0]),decodeURIComponent(m[1])]);return d}function f(b){for(var f=new FormData,d=0;d<b.length;d++)f.append(b[d].name,b[d].value);if(a.extraData)for(b=g(a.extraData),d=0;d<b.length;d++)b[d]&&f.append(b[d][0],b[d][1]);a.data=null;d=c.extend(!0,{},c.ajaxSettings,a,{contentType:!1,
processData:!1,cache:!1,type:m||"POST"});a.uploadProgress&&(d.xhr=function(){var b=c.ajaxSettings.xhr();b.upload&&b.upload.addEventListener("progress",function(c){var e=0,b=c.loaded||c.position,d=c.total;c.lengthComputable&&(e=Math.ceil(b/d*100));a.uploadProgress(c,b,d,e)},!1);return b});d.data=null;var k=d.beforeSend;d.beforeSend=function(c,b){b.data=a.formData?a.formData:f;k&&k.call(this,c,b)};return c.ajax(d)}function b(b){function d(a){var c=null;try{a.contentWindow&&(c=a.contentWindow.document)}catch(b){q("cannot get iframe.contentWindow document: "+
b)}if(c)return c;try{c=a.contentDocument?a.contentDocument:a.document}catch(e){q("cannot get iframe.contentDocument: "+e),c=a.document}return c}function f(){function a(){try{var c=d(v).readyState;q("state = "+c);c&&"uninitialized"==c.toLowerCase()&&setTimeout(a,50)}catch(b){q("Server abort: ",b," (",b.name,")"),g(z),u&&clearTimeout(u),u=void 0}}var b=p.attr2("target"),h=p.attr2("action");k.setAttribute("target",s);m&&!/post/i.test(m)||k.setAttribute("method","POST");h!=e.url&&k.setAttribute("action",
e.url);e.skipEncodingOverride||m&&!/post/i.test(m)||p.attr({encoding:"multipart/form-data",enctype:"multipart/form-data"});e.timeout&&(u=setTimeout(function(){y=!0;g(A)},e.timeout));var l=[];try{if(e.extraData)for(var n in e.extraData)e.extraData.hasOwnProperty(n)&&(c.isPlainObject(e.extraData[n])&&e.extraData[n].hasOwnProperty("name")&&e.extraData[n].hasOwnProperty("value")?l.push(c('<input type="hidden" name="'+e.extraData[n].name+'">').val(e.extraData[n].value).appendTo(k)[0]):l.push(c('<input type="hidden" name="'+
n+'">').val(e.extraData[n]).appendTo(k)[0]));e.iframeTarget||w.appendTo("body");v.attachEvent?v.attachEvent("onload",g):v.addEventListener("load",g,!1);setTimeout(a,15);try{k.submit()}catch(r){document.createElement("form").submit.apply(k)}}finally{k.setAttribute("action",h),b?k.setAttribute("target",b):p.removeAttr("target"),c(l).remove()}}function g(a){if(!h.aborted&&!F)if(r=d(v),r||(q("cannot access response document"),a=z),a===A&&h)h.abort("timeout"),x.reject(h,"timeout");else if(a==z&&h)h.abort("server abort"),
x.reject(h,"error","server abort");else if(r&&r.location.href!=e.iframeSrc||y){v.detachEvent?v.detachEvent("onload",g):v.removeEventListener("load",g,!1);a="success";var b;try{if(y)throw"timeout";var f="xml"==e.dataType||r.XMLDocument||c.isXMLDoc(r);q("isXml="+f);if(!f&&window.opera&&(null===r.body||!r.body.innerHTML)&&--C){q("requeing onLoad callback, DOM not available");setTimeout(g,250);return}var k=r.body?r.body:r.documentElement;h.responseText=k?k.innerHTML:null;h.responseXML=r.XMLDocument?r.XMLDocument:
r;f&&(e.dataType="xml");h.getResponseHeader=function(a){return{"content-type":e.dataType}[a.toLowerCase()]};k&&(h.status=Number(k.getAttribute("status"))||h.status,h.statusText=k.getAttribute("statusText")||h.statusText);var l=(e.dataType||"").toLowerCase(),m=/(json|script|text)/.test(l);if(m||e.textarea){var n=r.getElementsByTagName("textarea")[0];if(n)h.responseText=n.value,h.status=Number(n.getAttribute("status"))||h.status,h.statusText=n.getAttribute("statusText")||h.statusText;else if(m){var p=
r.getElementsByTagName("pre")[0],s=r.getElementsByTagName("body")[0];p?h.responseText=p.textContent?p.textContent:p.innerText:s&&(h.responseText=s.textContent?s.textContent:s.innerText)}}else"xml"==l&&!h.responseXML&&h.responseText&&(h.responseXML=H(h.responseText));try{B=I(h,l,e)}catch(G){a="parsererror",h.error=b=G||a}}catch(E){q("error caught: ",E),a="error",h.error=b=E||a}h.aborted&&(q("upload aborted"),a=null);h.status&&(a=200<=h.status&&300>h.status||304===h.status?"success":"error");"success"===
a?(e.success&&e.success.call(e.context,B,"success",h),x.resolve(h.responseText,"success",h),t&&c.event.trigger("ajaxSuccess",[h,e])):a&&(void 0===b&&(b=h.statusText),e.error&&e.error.call(e.context,h,a,b),x.reject(h,"error",b),t&&c.event.trigger("ajaxError",[h,e,b]));t&&c.event.trigger("ajaxComplete",[h,e]);t&&!--c.active&&c.event.trigger("ajaxStop");e.complete&&e.complete.call(e.context,h,a);F=!0;e.timeout&&clearTimeout(u);setTimeout(function(){e.iframeTarget?w.attr("src",e.iframeSrc):w.remove();
h.responseXML=null},100)}}var k=p[0],l,e,t,s,w,v,h,y,u,x=c.Deferred();x.abort=function(a){h.abort(a)};if(b)for(l=0;l<n.length;l++)b=c(n[l]),D?b.prop("disabled",!1):b.removeAttr("disabled");e=c.extend(!0,{},c.ajaxSettings,a);e.context=e.context||e;s="jqFormIO"+(new Date).getTime();e.iframeTarget?(w=c(e.iframeTarget),(l=w.attr2("name"))?s=l:w.attr2("name",s)):(w=c('<iframe name="'+s+'" src="'+e.iframeSrc+'" />'),w.css({position:"absolute",top:"-1000px",left:"-1000px"}));v=w[0];h={aborted:0,responseText:null,
responseXML:null,status:0,statusText:"n/a",getAllResponseHeaders:function(){},getResponseHeader:function(){},setRequestHeader:function(){},abort:function(a){var b="timeout"===a?"timeout":"aborted";q("aborting upload... "+b);this.aborted=1;try{v.contentWindow.document.execCommand&&v.contentWindow.document.execCommand("Stop")}catch(d){}w.attr("src",e.iframeSrc);h.error=b;e.error&&e.error.call(e.context,h,b,a);t&&c.event.trigger("ajaxError",[h,e,b]);e.complete&&e.complete.call(e.context,h,b)}};(t=e.global)&&
0===c.active++&&c.event.trigger("ajaxStart");t&&c.event.trigger("ajaxSend",[h,e]);if(e.beforeSend&&!1===e.beforeSend.call(e.context,h,e))return e.global&&c.active--,x.reject(),x;if(h.aborted)return x.reject(),x;(b=k.clk)&&(l=b.name)&&!b.disabled&&(e.extraData=e.extraData||{},e.extraData[l]=b.value,"image"==b.type&&(e.extraData[l+".x"]=k.clk_x,e.extraData[l+".y"]=k.clk_y));var A=1,z=2;b=c("meta[name=csrf-token]").attr("content");(l=c("meta[name=csrf-param]").attr("content"))&&b&&(e.extraData=e.extraData||
{},e.extraData[l]=b);e.forceSync?f():setTimeout(f,10);var B,r,C=50,F,H=c.parseXML||function(a,b){window.ActiveXObject?(b=new ActiveXObject("Microsoft.XMLDOM"),b.async="false",b.loadXML(a)):b=(new DOMParser).parseFromString(a,"text/xml");return b&&b.documentElement&&"parsererror"!=b.documentElement.nodeName?b:null},J=c.parseJSON||function(a){return window.eval("("+a+")")},I=function(a,b,e){var d=a.getResponseHeader("content-type")||"",f="xml"===b||!b&&0<=d.indexOf("xml");a=f?a.responseXML:a.responseText;
f&&"parsererror"===a.documentElement.nodeName&&c.error&&c.error("parsererror");e&&e.dataFilter&&(a=e.dataFilter(a,b));"string"===typeof a&&("json"===b||!b&&0<=d.indexOf("json")?a=J(a):("script"===b||!b&&0<=d.indexOf("javascript"))&&c.globalEval(a));return a};return x}if(!this.length)return q("ajaxSubmit: skipping submit process - no element selected"),this;var m,d,p=this;"function"==typeof a?a={success:a}:void 0===a&&(a={});m=a.type||this.attr2("method");d=a.url||this.attr2("action");(d=(d="string"===
typeof d?c.trim(d):"")||window.location.href||"")&&(d=(d.match(/^([^#]+)/)||[])[1]);a=c.extend(!0,{url:d,success:c.ajaxSettings.success,type:m||c.ajaxSettings.type,iframeSrc:/^https/i.test(window.location.href||"")?"javascript:false":"about:blank"},a);d={};this.trigger("form-pre-serialize",[this,a,d]);if(d.veto)return q("ajaxSubmit: submit vetoed via form-pre-serialize trigger"),this;if(a.beforeSerialize&&!1===a.beforeSerialize(this,a))return q("ajaxSubmit: submit aborted via beforeSerialize callback"),
this;var l=a.traditional;void 0===l&&(l=c.ajaxSettings.traditional);var n=[],k,t=this.formToArray(a.semantic,n);a.data&&(a.extraData=a.data,k=c.param(a.data,l));if(a.beforeSubmit&&!1===a.beforeSubmit(t,this,a))return q("ajaxSubmit: submit aborted via beforeSubmit callback"),this;this.trigger("form-submit-validate",[t,this,a,d]);if(d.veto)return q("ajaxSubmit: submit vetoed via form-submit-validate trigger"),this;d=c.param(t,l);k&&(d=d?d+"&"+k:k);"GET"==a.type.toUpperCase()?(a.url+=(0<=a.url.indexOf("?")?
"&":"?")+d,a.data=null):a.data=d;var s=[];a.resetForm&&s.push(function(){p.resetForm()});a.clearForm&&s.push(function(){p.clearForm(a.includeHidden)});if(!a.dataType&&a.target){var y=a.success||function(){};s.push(function(b){var d=a.replaceTarget?"replaceWith":"html";c(a.target)[d](b).each(y,arguments)})}else a.success&&s.push(a.success);a.success=function(b,c,d){for(var f=a.context||this,g=0,k=s.length;g<k;g++)s[g].apply(f,[b,c,d||p,p])};if(a.error){var u=a.error;a.error=function(b,c,d){u.apply(a.context||
this,[b,c,d,p])}}if(a.complete){var C=a.complete;a.complete=function(b,c){C.apply(a.context||this,[b,c,p])}}k=0<c("input[type=file]:enabled",this).filter(function(){return""!==c(this).val()}).length;d="multipart/form-data"==p.attr("enctype")||"multipart/form-data"==p.attr("encoding");l=z&&B;q("fileAPI :"+l);var A;!1!==a.iframe&&(a.iframe||(k||d)&&!l)?a.closeKeepAlive?c.get(a.closeKeepAlive,function(){A=b(t)}):A=b(t):A=(k||d)&&l?f(t):c.ajax(a);p.removeData("jqxhr").data("jqxhr",A);for(k=0;k<n.length;k++)n[k]=
null;this.trigger("form-submit-notify",[this,a]);return this};c.fn.ajaxForm=function(a){a=a||{};a.delegation=a.delegation&&c.isFunction(c.fn.on);if(!a.delegation&&0===this.length){var g=this.selector,f=this.context;if(!c.isReady&&g)return q("DOM not ready, queuing ajaxForm"),c(function(){c(g,f).ajaxForm(a)}),this;q("terminating; zero elements found by selector"+(c.isReady?"":" (DOM not ready)"));return this}return a.delegation?(c(document).off("submit.form-plugin",this.selector,y).off("click.form-plugin",
this.selector,u).on("submit.form-plugin",this.selector,a,y).on("click.form-plugin",this.selector,a,u),this):this.ajaxFormUnbind().bind("submit.form-plugin",a,y).bind("click.form-plugin",a,u)};c.fn.ajaxFormUnbind=function(){return this.unbind("submit.form-plugin click.form-plugin")};c.fn.formToArray=function(a,g){var f=[];if(0===this.length)return f;var b=this[0],m=a?b.getElementsByTagName("*"):b.elements;if(!m)return f;var d,p,l,n,k,q;d=0;for(q=m.length;d<q;d++)if(k=m[d],(l=k.name)&&!k.disabled)if(a&&
b.clk&&"image"==k.type)b.clk==k&&(f.push({name:l,value:c(k).val(),type:k.type}),f.push({name:l+".x",value:b.clk_x},{name:l+".y",value:b.clk_y}));else if((n=c.fieldValue(k,!0))&&n.constructor==Array)for(g&&g.push(k),p=0,k=n.length;p<k;p++)f.push({name:l,value:n[p]});else if(z&&"file"==k.type)if(g&&g.push(k),n=k.files,n.length)for(p=0;p<n.length;p++)f.push({name:l,value:n[p],type:k.type});else f.push({name:l,value:"",type:k.type});else null!==n&&"undefined"!=typeof n&&(g&&g.push(k),f.push({name:l,value:n,
type:k.type,required:k.required}));!a&&b.clk&&(m=c(b.clk),d=m[0],(l=d.name)&&!d.disabled&&"image"==d.type&&(f.push({name:l,value:m.val()}),f.push({name:l+".x",value:b.clk_x},{name:l+".y",value:b.clk_y})));return f};c.fn.formSerialize=function(a){return c.param(this.formToArray(a))};c.fn.fieldSerialize=function(a){var g=[];this.each(function(){var f=this.name;if(f){var b=c.fieldValue(this,a);if(b&&b.constructor==Array)for(var m=0,d=b.length;m<d;m++)g.push({name:f,value:b[m]});else null!==b&&"undefined"!=
typeof b&&g.push({name:this.name,value:b})}});return c.param(g)};c.fn.fieldValue=function(a){for(var g=[],f=0,b=this.length;f<b;f++){var m=c.fieldValue(this[f],a);null===m||"undefined"==typeof m||m.constructor==Array&&!m.length||(m.constructor==Array?c.merge(g,m):g.push(m))}return g};c.fieldValue=function(a,g){var f=a.name,b=a.type,m=a.tagName.toLowerCase();void 0===g&&(g=!0);if(g&&(!f||a.disabled||"reset"==b||"button"==b||("checkbox"==b||"radio"==b)&&!a.checked||("submit"==b||"image"==b)&&a.form&&
a.form.clk!=a||"select"==m&&-1==a.selectedIndex))return null;if("select"==m){var d=a.selectedIndex;if(0>d)return null;for(var f=[],m=a.options,p=(b="select-one"==b)?d+1:m.length,d=b?d:0;d<p;d++){var l=m[d];if(l.selected){var n=l.value;n||(n=l.attributes&&l.attributes.value&&!l.attributes.value.specified?l.text:l.value);if(b)return n;f.push(n)}}return f}return c(a).val()};c.fn.clearForm=function(a){return this.each(function(){c("input,select,textarea",this).clearFields(a)})};c.fn.clearFields=c.fn.clearInputs=
function(a){var g=/^(?:color|date|datetime|email|month|number|password|range|search|tel|text|time|url|week)$/i;return this.each(function(){var f=this.type,b=this.tagName.toLowerCase();g.test(f)||"textarea"==b?this.value="":"checkbox"==f||"radio"==f?this.checked=!1:"select"==b?this.selectedIndex=-1:"file"==f?/MSIE/.test(navigator.userAgent)?c(this).replaceWith(c(this).clone(!0)):c(this).val(""):a&&(!0===a&&/hidden/.test(f)||"string"==typeof a&&c(this).is(a))&&(this.value="")})};c.fn.resetForm=function(){return this.each(function(){("function"==
typeof this.reset||"object"==typeof this.reset&&!this.reset.nodeType)&&this.reset()})};c.fn.enable=function(a){void 0===a&&(a=!0);return this.each(function(){this.disabled=!a})};c.fn.selected=function(a){void 0===a&&(a=!0);return this.each(function(){var g=this.type;"checkbox"==g||"radio"==g?this.checked=a:"option"==this.tagName.toLowerCase()&&(g=c(this).parent("select"),a&&g[0]&&"select-one"==g[0].type&&g.find("option").selected(!1),this.selected=a)})};c.fn.ajaxSubmit.debug=!1})("undefined"!=typeof jQuery?
jQuery:window.Zepto);
