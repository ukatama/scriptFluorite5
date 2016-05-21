/*
 * Fluorite 5.8.1
 * ==============
 */

{

  function createCodeFromLiteral(type, value)
  {
    return function(vm, context, args) {
      return vm.createLiteral(type, value, context, args);
    };
  }

  function createCodeFromMethod(operator, codes)
  {
    return function(vm, context, args) {
      return vm.callMethod(operator, codes, context, args);
    };
  }

  function operatorLeft(head, tail)
  {
    var result = head, i;
    for (i = 0; i < tail.length; i++) {
      var operator = tail[i][1];
      if ((typeof operator) === "string") {
        result = createCodeFromMethod("_operator" + operator, [result, tail[i][3]]);
      } else {
        result = createCodeFromMethod("_operator" + operator[0], [result, operator[1], tail[i][3]]);
      }
    }
    return result;
  }

  function operatorRight(head, tail)
  {
    var result = tail, i;
    for (i = head.length - 1; i >= 0; i--) {
      var operator = head[i][2];
      if ((typeof operator) === "string") {
        result = createCodeFromMethod("_operator" + operator, [head[i][0], result]);
      } else {
        result = createCodeFromMethod("_operator" + operator[0], [head[i][0], operator[1], result]);
      }
    }
    return result;
  }

  function left(head, tail)
  {
    var result = tail, i;
    for (i = head.length - 1; i >= 0; i--) {
      var operator = head[i][0];
      if ((typeof operator) === "string") {
        result = createCodeFromMethod("_left" + operator, [result]);
      } else {
        result = createCodeFromMethod("_left" + operator[0], [operator[1], result]);
      }
    }
    return result;
  }

  function right(head, tail)
  {
    var result = head, i;
    for (i = 0; i < tail.length; i++) {
      var args = [result];
      Array.prototype.push.apply(args, tail[i][1][1]);
      result = createCodeFromMethod(tail[i][1][0], args);
    }
    return result;
  }

  function enumerate(head, tail, operator)
  {
    if (tail.length == 0) return head;
    var result = [head], i;
    for (i = 0; i < tail.length; i++) {
      result.push(tail[i][3]);
    }
    return createCodeFromMethod("_enumerate" + operator, result);
  }

  function getVM(name)
  {
    if (name === "classic") {
      return function() {
        var vm = this;

        function dice(count, faces)
        {
          var t = 0, i, value, values = [];
          for (i = 0; i < count; i++) {
            value = Math.floor(Math.random() * faces) + 1;
            t += value;
            values.push(value);
          }
          vm.dices.push(values);
          return t;
        }

        this.dices = [];
        this.callMethod = function(operator, codes, context, args) {

          if (context === "get") {

            if (operator === "_operatorPlus") return codes[0](vm, "get") + codes[1](vm, "get");
            if (operator === "_operatorMinus") return codes[0](vm, "get") - codes[1](vm, "get");
            if (operator === "_operatorAsterisk") return codes[0](vm, "get") * codes[1](vm, "get");
            if (operator === "_operatorSlash") return codes[0](vm, "get") / codes[1](vm, "get");
            if (operator === "_leftPlus") return codes[0](vm, "get");
            if (operator === "_leftMinus") return -codes[0](vm, "get");
            if (operator === "_bracketsRound") return codes[0](vm, "get");
            if (operator === "_operatorComposite") return dice(codes[0](vm, "get"), codes[2](vm, "get"));

            throw "Unknown operator: " + operator;
          } else {
            throw "Unknown context: " + context;
          }
        };
        this.toString = function(value) {
          return "" + value;
        };
        this.toNative = function(value) {
          return value;
        };
        this.toBoolean = function(value) {
          return value;
        };
        this.createLiteral = function(type, value, context, args) {
          return value;
        };
      };
    } else if (name === "standard") {
      return (function() {

        function getProperty(hash, name)
        {
          var variable = Object.getOwnPropertyDescriptor(hash, name);
          if (variable != undefined) variable = variable.value;
          return variable;
        }

        function Scope(parent, isFrame, UNDEFINED)
        {
          this.variables = {};
          this.parent = parent;
          this.isFrame = isFrame;
          this.id = Math.floor(Math.random() * 1000000);
          this.UNDEFINED = UNDEFINED;
        }
        Scope.prototype.getVariable = function(name) {
          var variable = getProperty(this.variables, name);
          if (variable != undefined) {
            return variable;
          } else {
            if (this.parent != undefined) {
              return this.parent.getVariable(name);
            } else {
              return undefined;
            }
          }
        };
        Scope.prototype.define = function(name) {
          if (this.getVariable(name) != undefined) {
            throw "Duplicate variable definition: " + name;
          } else {
            this.variables[name] = {
              value: this.UNDEFINED,
            };
          }
        };
        Scope.prototype.get = function(name) {
          var variable = this.getVariable(name);
          if (variable != undefined) {
            return variable.value;
          } else {
            throw "Unknown variable: " + name;
          }
        };
        Scope.prototype.getOrUndefined = function(name) {
          var variable = this.getVariable(name);
          if (variable != undefined) {
            return variable.value;
          } else {
            return this.UNDEFINED;
          }
        };
        Scope.prototype.set = function(name, value) {
          var variable = this.getVariable(name);
          if (variable != undefined) {
            variable.value = value;
          } else {
            throw "Unknown variable: " + name;
          }
        };
        Scope.prototype.setOrDefine = function(name, value) {
          var variable = this.getVariable(name);
          if (variable != undefined) {
            variable.value = value;
          } else {
            this.variables[name] = {
              value: value,
            };
          }
        };
        Scope.prototype.defineOrSet = function(name, value) {
          var variable = getProperty(this.variables, name);
          if (variable != undefined) {
            variable.value = value;
          } else {
            this.variables[name] = {
              value: value,
            };
          }
        };
        Scope.prototype.getParentFrame = function(name, value) {
          if (this.parent.isFrame) {
            return this.parent;
          } else {
            return this.parent.getParentFrame();
          }
        };

        function VMStandard()
        {
          var vm = this;

          var listenersInitializeFinished = [];

          function callInFrame(code, vm, context, args)
          {
            vm.pushFrame();
            var res;
            try {
              res = code(vm, context, args);
            } finally {
              vm.popFrame();
            }
            return res;
          }
          function dice(count, faces)
          {
            var t = 0, i, value, values = [];
            for (i = 0; i < count; i++) {
              value = Math.floor(Math.random() * faces) + 1;
              t += value;
              values.push(value);
            }
            vm.dices.push(values);
            return t;
          }
          function visitScalar(array, blessed)
          {
            if (instanceOf(blessed, vm.types.typeVector)) {
              for (var i = 0; i < blessed.value.length; i++) {
                visitScalar(array, blessed.value[i]);
              }
            } else {
              array.push(blessed);
            }
          }
          function packVector(array)
          {
            var array2 = [];
            array.forEach(function(item) { visitScalar(array2, item); });
            if (array2.length == 1) return array2[0];
            return vm.createObject(vm.types.typeVector, array2);
          }
          function unpackVector(blessed)
          {
            if (instanceOf(blessed, vm.types.typeVector)) return blessed.value;
            return [blessed];
          }
          function instanceOf(blessed, blessedType2)
          {
            if ((typeof blessed) !== "object") return false;
            if (blessed.type === undefined) return false;

            var blessedType = blessed.type;

            while (blessedType !== null) {
              if (blessedType == blessedType2) return true;
              blessedType = blessedType.value.supertype;
            }

            return false;
          }
          function callFunction(blessedFunction, blessedArgs)
          {
            var i;
            var array = unpackVector(blessedArgs);
            vm.pushStack(blessedFunction.value.scope);
            vm.pushFrame();
            for (i = 0; i < blessedFunction.value.args.length; i++) {
              vm.scope.defineOrSet(blessedFunction.value.args[i], array[i] || vm.UNDEFINED);
            }
            vm.scope.defineOrSet("_", packVector(array.slice(i, array.length)));
            var res;
            try {
              res = blessedFunction.value.code(vm, "get");
            } finally {
              vm.popFrame();
              vm.popStack();
            }
            return res;
          }
          function callPointer(blessedPointer, context, args)
          {
            vm.pushStack(blessedPointer.value.scope);
            var res;
            try {
              res = blessedPointer.value.code(vm, context, args);
            } finally {
              vm.popStack();
            }
            return res;
          }
          function searchVariable(accesses, keyword)
          {
            var variable;

            for (var i = 0; i < accesses.length; i++) {
              variable = vm.scope.getOrUndefined("_" + accesses[i] + "_" + keyword);
              if (!instanceOf(variable, vm.types.typeUndefined)) return variable;
            }

            variable = vm.scope.getOrUndefined(keyword);
            if (!instanceOf(variable, vm.types.typeUndefined)) return variable;

            return vm.UNDEFINED;
          }
          function searchVariableWithType(keyword, blessedType)
          {
            var variable;

            while (blessedType !== null) {

              variable = getPropertyBlessed(blessedType.value.members, keyword);
              if (!instanceOf(variable, vm.types.typeUndefined)) return variable;

              blessedType = blessedType.value.supertype;
            }

            return searchVariable(["method", "function"], keyword);
          }
          function getMethodsOfTypeTree(keyword, blessedType)
          {
            var f;
            var functions = [];

            while (blessedType !== null) {

              f = getPropertyBlessed(blessedType.value.members, keyword);
              if (!instanceOf(f, vm.types.typeUndefined)) {
                functions.push(f);
              }

              blessedType = blessedType.value.supertype;
            }

            return functions;
          }
          function createType(name, supertype, providesPrimitiveConstructor)
          {
            var blessedType = vm.createObject(vm.types.typeType, {
              name: name,
              supertype: supertype,
              members: {},
            });

            if (providesPrimitiveConstructor) {
              var f = function() {
                blessedType.value.members["new"] = vm.createFunction(["type"], function(vm, context) {
                  var blessedValue = vm.scope.getOrUndefined("type");
                  if (instanceOf(blessedValue, blessedType)) return blessedValue;
                  throw "Construct Error: Expected " + blessedType.value.name + " but " + blessedValue.type.value.name;
                }, vm.scope);
              };
              if (listenersInitializeFinished === null) {
                f();
              } else {
                listenersInitializeFinished.push(f);
              }
            }

            return blessedType;
          }
          function getMethodOfBlessed(blessed, blessedName)
          {
            if (instanceOf(blessedName, vm.types.typeKeyword)) blessedName = searchVariableWithType(blessedName.value, blessed.type);
            if (instanceOf(blessedName, vm.types.typeFunction)) {
              return vm.createFunction([], function(vm, context, args) {
                var array = unpackVector(vm.scope.getOrUndefined("_"));
                array.unshift(blessed);
                return callFunction(blessedName, packVector(array));
              }, vm.scope);
            }
            throw "Type Error: " + blessed.type.value.name + "." + blessedName.type.value.name;
          }
          function callMethodOfBlessed(blessed, blessedName, blessedArgs)
          {
            return callFunction(getMethodOfBlessed(blessed, blessedName), blessedArgs);
          }
          function getPropertyBlessed(hash, name)
          {
            var variable = Object.getOwnPropertyDescriptor(hash, name);
            if (variable != undefined) variable = variable.value;
            variable = variable || vm.UNDEFINED;
            return variable;
          }


          vm.types = {};
           vm.types.typeType = createType("Type", null, false);
           vm.types.typeValue = createType("Value", null, false);
             vm.types.typeUndefined = createType("Undefined", vm.types.typeValue, false);
             vm.types.typeDefined = createType("Defined", vm.types.typeValue, false);
               vm.types.typeNull = createType("Null", vm.types.typeDefined, false);
               vm.types.typeNumber = createType("Number", vm.types.typeDefined, true);
               vm.types.typeString = createType("String", vm.types.typeDefined, true);
                 vm.types.typeKeyword = createType("Keyword", vm.types.typeString, false);
               vm.types.typeBoolean = createType("Boolean", vm.types.typeDefined, true);
               vm.types.typeFunction = createType("Function", vm.types.typeDefined, true);
               vm.types.typePointer = createType("Pointer", vm.types.typeDefined, true);
               vm.types.typeArray = createType("Array", vm.types.typeDefined, true);
                 vm.types.typeVector = createType("Vector", vm.types.typeArray, false);
               vm.types.typeObject = createType("Object", vm.types.typeDefined, true);
                 vm.types.typeHash = createType("Hash", vm.types.typeObject, false);
                 vm.types.typeEntry = createType("Entry", vm.types.typeObject, false);
                 vm.types.typeException = createType("Exception", vm.types.typeObject, false);
          vm.types.typeType.type = vm.types.typeType;
          vm.types.typeType.value.supertype = vm.types.typeDefined;

          vm.UNDEFINED = vm.createObject(vm.types.typeUndefined, undefined);
          vm.NULL = vm.createObject(vm.types.typeNull, null);
          vm.VOID = packVector([]);
          vm.TRUE = vm.createObject(vm.types.typeBoolean, true);
          vm.FALSE = vm.createObject(vm.types.typeBoolean, false);

          this.scope = new Scope(null, true, vm.UNDEFINED);
          this.stack = [];

          listenersInitializeFinished.map(function(a) { a(); })
          listenersInitializeFinished = null;

          vm.types.typeValue.value.members["toString"] = vm.createFunction(["this"], function(vm, context) {
            var value = vm.scope.getOrUndefined("this");
            return vm.createObject(vm.types.typeString, "<" + value.type.value.name + ">");
          }, vm.scope);
          vm.types.typeNumber.value.members["toString"] = vm.createFunction(["this"], function(vm, context) {
            var value = vm.scope.getOrUndefined("this");
            return vm.createObject(vm.types.typeString, "" + value.value);
          }, vm.scope);
          vm.types.typeString.value.members["toString"] = vm.createFunction(["this"], function(vm, context) {
            var value = vm.scope.getOrUndefined("this");
            return vm.createObject(vm.types.typeString, value.value);
          }, vm.scope);
          vm.types.typeBoolean.value.members["toString"] = vm.createFunction(["this"], function(vm, context) {
            var value = vm.scope.getOrUndefined("this");
            return vm.createObject(vm.types.typeString, "" + value.value);
          }, vm.scope);
          vm.types.typeArray.value.members["toString"] = vm.createFunction(["this"], function(vm, context) {
            var value = vm.scope.getOrUndefined("this");
            return vm.createObject(vm.types.typeString, "[" + value.value.map(function(scalar) { return vm.toString(scalar); }).join(", ") + "]");
          }, vm.scope);
          vm.types.typeHash.value.members["toString"] = vm.createFunction(["this"], function(vm, context) {
            var value = vm.scope.getOrUndefined("this");
            return vm.createObject(vm.types.typeString, "{" + Object.keys(value.value).map(function(key) {
              return key + ": " + vm.toString(value.value[key]);
            }).join(", ") + "}");
          }, vm.scope);
          vm.types.typeEntry.value.members["toString"] = vm.createFunction(["this"], function(vm, context) {
            var value = vm.scope.getOrUndefined("this");
            return vm.createObject(vm.types.typeString, vm.toString(value.value.key) + ": " + vm.toString(value.value.value));
          }, vm.scope);
          vm.types.typeVector.value.members["toString"] = vm.createFunction([], function(vm, context) {
            var value = vm.scope.getOrUndefined("_");
            if (value.value.length == 0) return vm.createObject(vm.types.typeString, "<Void>");
            return vm.createObject(vm.types.typeString, value.value.map(function(scalar) { return vm.toString(scalar); }).join(", "));
          }, vm.scope);
          vm.types.typeType.value.members["toString"] = vm.createFunction(["this"], function(vm, context) {
            var value = vm.scope.getOrUndefined("this");
            return vm.createObject(vm.types.typeString, "<Type: " + value.value.name + ">");
          }, vm.scope);
          vm.types.typeFunction.value.members["toString"] = vm.createFunction(["this"], function(vm, context) {
            var value = vm.scope.getOrUndefined("this");
            if (value.value.args.length === 0) return vm.createObject(vm.types.typeString, "<Function>");
            return vm.createObject(vm.types.typeString, "<Function: " + value.value.args.join(", ") + ">");
          }, vm.scope);
          vm.types.typeException.value.members["toString"] = vm.createFunction(["this"], function(vm, context) {
            var value = vm.scope.getOrUndefined("this");
            return vm.createObject(vm.types.typeString, "<Exception: '" + value.value.message + "'>");
          }, vm.scope);

          {
            var hash = {};
            Object.keys(vm.types).forEach(function(key) {
              hash[vm.types[key].value.name] = vm.types[key];
            });
            vm.scope.setOrDefine("fluorite", vm.createObject(vm.types.typeHash, {
              "type": vm.createObject(vm.types.typeHash, hash),
            }));
          }
          Object.keys(vm.types).forEach(function(key) {
            vm.scope.setOrDefine("_class_" + vm.types[key].value.name, vm.types[key]);
          });
          function createNativeBridge(func, argumentCount)
          {
            if (argumentCount == 0) {
              return vm.createFunction([], function(vm, context) {
                return vm.createObject(vm.types.typeNumber, func());
              }, vm.scope);
            } else if (argumentCount == 1) {
              return vm.createFunction(["x"], function(vm, context) {
                return vm.createObject(vm.types.typeNumber, func(vm.scope.getOrUndefined("x").value));
              }, vm.scope);
            } else if (argumentCount == 2) {
              return vm.createFunction(["x", "y"], function(vm, context) {
                return vm.createObject(vm.types.typeNumber, func(vm.scope.getOrUndefined("x").value, vm.scope.getOrUndefined("y").value));
              }, vm.scope);
            } else {
              throw "TODO"; // TODO
            }
          }
          vm.scope.setOrDefine("Math", vm.createObject(vm.types.typeHash, {
            "PI": vm.createObject(vm.types.typeNumber, Math.PI),
            "E": vm.createObject(vm.types.typeNumber, Math.E),
            "abs": createNativeBridge(Math.abs, 1),
            "sin": createNativeBridge(Math.sin, 1),
            "cos": createNativeBridge(Math.cos, 1),
            "tan": createNativeBridge(Math.tan, 1),
            "asin": createNativeBridge(Math.asin, 1),
            "acos": createNativeBridge(Math.acos, 1),
            "atan": createNativeBridge(Math.atan, 1),
            "atan2": createNativeBridge(Math.atan2, 2),
            "log": createNativeBridge(Math.log, 1),
            "ceil": createNativeBridge(Math.ceil, 1),
            "floor": createNativeBridge(Math.floor, 1),
            "exp": createNativeBridge(Math.exp, 1),
            "pow": createNativeBridge(Math.pow, 2),
            "random": createNativeBridge(Math.random, 0),
            "randomBetween": createNativeBridge(function(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }, 2),
            "sqrt": createNativeBridge(Math.sqrt, 1),
          }));
          vm.scope.setOrDefine("_rightComposite_d", vm.createFunction(["count"], function(vm, context) {
            var count = vm.scope.getOrUndefined("count");
            if (!instanceOf(count, vm.types.typeNumber)) throw "Illegal argument[0]: " + count.type.value.name + " != Number";
            if (count.value > 20) throw vm.createException("Illegal argument[0]: " + count.value + " > 20");
            return vm.createObject(vm.types.typeNumber, dice(count.value, 6));
          }, vm.scope));
          vm.scope.setOrDefine("_function_d", vm.createFunction(["count", "faces"], function(vm, context) {
            var count = vm.scope.getOrUndefined("count");
            var faces = vm.scope.getOrUndefined("faces");
            if (!instanceOf(count, vm.types.typeNumber)) throw "Illegal argument[0]: " + count.type.value.name + " != Number";
            if (count.value > 20) throw vm.createException("Illegal argument[0]: " + count.value + " > 20");
            if (!instanceOf(faces, vm.types.typeNumber)) throw "Illegal argument[1]: " + faces.type.value.name + " != Number";
            return vm.createObject(vm.types.typeNumber, dice(count.value, faces.value));
          }, vm.scope));
          vm.scope.setOrDefine("_leftMultibyte_√", vm.createFunction(["x"], function(vm, context) {
            var x = vm.scope.getOrUndefined("x");
            if (!instanceOf(x, vm.types.typeNumber)) throw "Illegal argument[0]: " + x.type.value.name + " != Number";
            return vm.createObject(vm.types.typeNumber, Math.sqrt(x.value));
          }, vm.scope));
          vm.scope.setOrDefine("_function_join", vm.createFunction(["separator"], function(vm, context) {
            var separator = vm.scope.getOrUndefined("separator");
            var vector = vm.scope.getOrUndefined("_");
            return vm.createObject(vm.types.typeString, unpackVector(vector).map(function(blessed) {
              return vm.toString(blessed);
            }).join(separator.value));
          }, vm.scope));
          vm.scope.setOrDefine("_function_join1", vm.createFunction([], function(vm, context) {
            var vector = vm.scope.getOrUndefined("_");
            return vm.createObject(vm.types.typeString, unpackVector(vector).map(function(blessed) {
              return vm.toString(blessed);
            }).join(""));
          }, vm.scope));
          vm.scope.setOrDefine("_function_join2", vm.createFunction([], function(vm, context) {
            var vector = vm.scope.getOrUndefined("_");
            return vm.createObject(vm.types.typeString, unpackVector(vector).map(function(blessed) {
              return vm.toString(blessed);
            }).join(", "));
          }, vm.scope));
          vm.scope.setOrDefine("_function_join3", vm.createFunction([], function(vm, context) {
            var vector = vm.scope.getOrUndefined("_");
            return vm.createObject(vm.types.typeString, unpackVector(vector).map(function(blessed) {
              return vm.toString(blessed);
            }).join("\n"));
          }, vm.scope));
          vm.scope.setOrDefine("_function_sum", vm.createFunction([], function(vm, context) {
            var value = 0;
            unpackVector(vm.scope.getOrUndefined("_")).forEach(function(blessed) {
              value += blessed.value;
            });
            return vm.createObject(vm.types.typeNumber, value);
          }, vm.scope));
          vm.scope.setOrDefine("_function_average", vm.createFunction([], function(vm, context) {
            var array = unpackVector(vm.scope.getOrUndefined("_"));
            if (array.length == 0) return vm.UNDEFINED;
            var value = 0;
            array.forEach(function(blessed) {
              value += blessed.value;
            });
            return vm.createObject(vm.types.typeNumber, value / array.length);
          }, vm.scope));
          vm.scope.setOrDefine("_function_count", vm.createFunction([], function(vm, context) {
            return vm.createObject(vm.types.typeNumber, unpackVector(vm.scope.getOrUndefined("_")).length);
          }, vm.scope));
          vm.scope.setOrDefine("_function_and", vm.createFunction([], function(vm, context) {
            var value = true;
            unpackVector(vm.scope.getOrUndefined("_")).forEach(function(blessed) {
              value = value && blessed.value;
            });
            return vm.getBoolean(value);
          }, vm.scope));
          vm.scope.setOrDefine("_function_or", vm.createFunction([], function(vm, context) {
            var value = false;
            unpackVector(vm.scope.getOrUndefined("_")).forEach(function(blessed) {
              value = value || blessed.value;
            });
            return vm.getBoolean(value);
          }, vm.scope));
          vm.scope.setOrDefine("_function_max", vm.createFunction([], function(vm, context) {
            var array = unpackVector(vm.scope.getOrUndefined("_"));
            if (array.length == 0) return vm.UNDEFINED;
            var value = array[0].value;
            for (var i = 1; i < array.length; i++) {
              if (value < array[i].value) value = array[i].value;
            }
            return vm.createObject(vm.types.typeNumber, value);
          }, vm.scope));
          vm.scope.setOrDefine("_function_min", vm.createFunction([], function(vm, context) {
            var array = unpackVector(vm.scope.getOrUndefined("_"));
            if (array.length == 0) return vm.UNDEFINED;
            var value = array[0].value;
            for (var i = 1; i < array.length; i++) {
              if (value > array[i].value) value = array[i].value;
            }
            return vm.createObject(vm.types.typeNumber, value);
          }, vm.scope));

          this.dices = [];
          this.loopCapacity = 10000;
          this.loopCount = 0;

          function consumeLoopCapacity()
          {
            vm.loopCount++;
            if (vm.loopCount >= vm.loopCapacity) {
              throw "Internal Fluorite Error: Too many calculation(>= " + vm.loopCapacity + " steps)";
            }
          }

          this.callMethod = function(operator, codes, context, args) {
            consumeLoopCapacity();

            {
              var name = "_" + context + operator;
              var func = vm.scope.getOrUndefined(name);
              if (!instanceOf(func, vm.types.typeUndefined)) {
                if (instanceOf(func, vm.types.typeFunction)) {
                  var array = [vm.createObject(vm.types.typeString, context)];
                  Array.prototype.push.apply(array, codes.map(function(code) { return vm.createPointer(code, vm.scope); }));
                  var pointer = callFunction(func, packVector(array));
                  if (!instanceOf(pointer, vm.types.typePointer)) throw "Illegal type of operation result: " + pointer.type.value.name;
                  return callPointer(pointer, context, args);
                } else {
                  throw "`" + name + "` is not a function";
                }
              }
            }

            {
              var name = operator;
              var func = vm.scope.getOrUndefined(name);
              if (!instanceOf(func, vm.types.typeUndefined)) {
                if (instanceOf(func, vm.types.typeFunction)) {
                  var array = [vm.createObject(vm.types.typeString, context)];
                  Array.prototype.push.apply(array, codes.map(function(code) { return vm.createPointer(code, vm.scope); }));
                  var pointer = callFunction(func, packVector(array));
                  if (!instanceOf(pointer, vm.types.typePointer)) throw "Illegal type of operation result: " + pointer.type.value.name;
                  return callPointer(pointer, context, args);
                } else {
                  throw "`" + name + "` is not a function";
                }
              }
            }

            if (context === "get") {

              if (operator === "_operatorPlus") {
                var left = codes[0](vm, "get");
                var right = codes[1](vm, "get");
                if (instanceOf(left, vm.types.typeNumber)) {
                  if (instanceOf(right, vm.types.typeNumber)) {
                    return vm.createObject(vm.types.typeNumber, left.value + right.value);
                  }
                }
                return vm.createObject(vm.types.typeString, vm.toString(left) + vm.toString(right));
              }
              if (operator === "_operatorMinus") return vm.createObject(vm.types.typeNumber, codes[0](vm, "get").value - codes[1](vm, "get").value);
              if (operator === "_operatorAsterisk") return vm.createObject(vm.types.typeNumber, codes[0](vm, "get").value * codes[1](vm, "get").value);
              if (operator === "_operatorPercent") return vm.createObject(vm.types.typeNumber, codes[0](vm, "get").value % codes[1](vm, "get").value);
              if (operator === "_operatorSlash") return vm.createObject(vm.types.typeNumber, codes[0](vm, "get").value / codes[1](vm, "get").value);
              if (operator === "_operatorCaret") return vm.createObject(vm.types.typeNumber, Math.pow(codes[0](vm, "get").value, codes[1](vm, "get").value));
              if (operator === "_leftPlus") return vm.createObject(vm.types.typeNumber, codes[0](vm, "get").value);
              if (operator === "_leftMinus") return vm.createObject(vm.types.typeNumber, -codes[0](vm, "get").value);
              if (operator === "_leftExclamation") return vm.getBoolean(!codes[0](vm, "get").value);
              if (operator === "_operatorGreater") return vm.getBoolean(codes[0](vm, "get").value > codes[1](vm, "get").value);
              if (operator === "_operatorGreaterEqual") return vm.getBoolean(codes[0](vm, "get").value >= codes[1](vm, "get").value);
              if (operator === "_operatorLess") return vm.getBoolean(codes[0](vm, "get").value < codes[1](vm, "get").value);
              if (operator === "_operatorLessEqual") return vm.getBoolean(codes[0](vm, "get").value <= codes[1](vm, "get").value);
              if (operator === "_operatorEqual2") return vm.getBoolean(codes[0](vm, "get").value == codes[1](vm, "get").value);
              if (operator === "_operatorExclamationEqual") return vm.getBoolean(codes[0](vm, "get").value != codes[1](vm, "get").value);
              if (operator === "_operatorPipe2") return vm.getBoolean(codes[0](vm, "get").value || codes[1](vm, "get").value);
              if (operator === "_operatorTilde") {
                var left = codes[0](vm, "get").value;
                var right = codes[1](vm, "get").value;
                var array = [];
                for (var i = left; i <= right; i++) {
                  array.push(vm.createObject(vm.types.typeNumber, i));
                }
                return packVector(array);
              }
              if (operator === "_operatorAmpersand2") return vm.getBoolean(codes[0](vm, "get").value && codes[1](vm, "get").value);
              if (operator === "_enumerateComma") return packVector(codes.map(function(code) { return code(vm, "get"); }));
              if (operator === "_bracketsSquare") {
                return vm.createObject(vm.types.typeArray, unpackVector(callInFrame(codes[0], vm, "get")));
              }
              if (operator === "_rightbracketsSquare") {
                var value = codes[0](vm, "get");
                if (instanceOf(value, vm.types.typeKeyword)) value = searchVariable(["array"], value.value);
                if (instanceOf(value, vm.types.typeArray)) return value.value[callInFrame(codes[1], vm, "get").value] || vm.UNDEFINED;
                throw "Type Error: " + operator + "/" + value.type.value.name;
              }
              if (operator === "_leftAtsign") {
                var value = codes[0](vm, "get");
                if (instanceOf(value, vm.types.typeArray)) return vm.createObject(vm.types.typeVector, value.value);
                throw "Type Error: " + operator + "/" + value.type.value.name;
              }
              if (operator === "_operatorMinus2Greater"
                || operator === "_operatorEqual2Greater") 	{
                var minus = operator == "_operatorMinus2Greater";
                if (minus) {
                  return packVector(unpackVector(codes[0](vm, "get")).map(function(scalar) {
                    return callFunction(vm.createFunction([], codes[1], vm.scope), scalar);
                  }));
                } else {
                  return callFunction(vm.createFunction([], codes[1], vm.scope), codes[0](vm, "get"));
                }
              }
              if (operator === "_operatorMinusGreater"
                || operator === "_operatorEqualGreater") 	{
                var minus = operator == "_operatorMinusGreater";
                var right = codes[1](vm, "get");
                if (minus) {
                  return packVector(unpackVector(codes[0](vm, "get")).map(function(scalar) {
                    return callMethodOfBlessed(scalar, right, vm.VOID);
                  }));
                } else {
                  return callMethodOfBlessed(codes[0](vm, "get"), right, vm.VOID);
                }
                throw "Type Error: " + operator + "/" + right.type.value.name;
              }
              if (operator === "_operatorColon") return vm.createObject(vm.types.typeEntry, {
                key: codes[0](vm, "get"),
                value: codes[1](vm, "get"),
              });
              if (operator === "_leftDollar") return vm.scope.getOrUndefined(codes[0](vm, "get").value);
              if (operator === "_rightbracketsRound") {
                var value = codes[0](vm, "get");
                if (instanceOf(value, vm.types.typeKeyword)) value = searchVariable(["function"], value.value);
                if (instanceOf(value, vm.types.typeFunction)) return callFunction(value, callInFrame(codes[1], vm, "get"));
                throw "Type Error: " + operator + "/" + value.type.value.name;
              }
              if (operator === "_statement") {
                var command = codes[0](vm, "get");
                if (!instanceOf(command, vm.types.typeKeyword)) throw "Type Error: " + command.type.value.name + " != String";
                if (command.value === "typeof") {
                  var value = codes[1](vm, "get");
                  return value.type;
                }
                if (command.value === "var") {
                  var array = unpackVector(codes[1](vm, "arguments"));
                  array.map(function(item) {
                    if (!instanceOf(item, vm.types.typeKeyword)) throw "Type Error: " + item.type.value.name + " != Keyword";
                    vm.scope.defineOrSet(item.value, vm.UNDEFINED);
                  });
                  return vm.UNDEFINED;
                }
                if (command.value === "console_scope") {
                  console.log(vm.scope);
                  return vm.UNDEFINED;
                }
                if (command.value === "console_log") {
                  var value = codes[1](vm, "get");
                  console.log(value);
                  return vm.UNDEFINED;
                }
                if (command.value === "call") {
                  var blessedOperator = codes[1](vm, "get");
                  if (!instanceOf(blessedOperator, vm.types.typeString)) throw "Type Error: " + blessedOperator.type.value.name + " != String";
                  var array = codes.slice(2, codes.length).map(function(item) {
                    return vm.createPointer(item, vm.scope);
                  })
                  return vm.callMethod(blessedOperator.value, array.map(function(item) {
                    return function(vm, context, args) {
                      return callPointer(item, context, args);
                    };
                  }), "get", []);
                }
                if (command.value === "instanceof") {
                  if (codes.length != 3) throw "Illegal command argument: " + command.value;
                  var value = codes[1](vm, "get");
                  var type = codes[2](vm, "get");
                  if (!instanceOf(type, vm.types.typeType)) throw "Type Error: " + type.type.value.name + " != Type";
                  return vm.getBoolean(instanceOf(value, type));
                }
                if (command.value === "length") {
                  var value = codes[1](vm, "get");
                  if (instanceOf(value, vm.types.typeArray)) return vm.createObject(vm.types.typeNumber, value.value.length);
                  if (instanceOf(value, vm.types.typeVector)) return vm.createObject(vm.types.typeNumber, value.value.length);
                  if (instanceOf(value, vm.types.typeString)) return vm.createObject(vm.types.typeNumber, value.value.length);
                  throw "Illegal Argument: " + value.type.value;
                }
                if (command.value === "keys") {
                  var value = codes[1](vm, "get");
                  if (!instanceOf(value, vm.types.typeHash)) throw "Type Error: " + value.type.value.name + " != Hash";
                  return packVector(Object.keys(value.value).map(function(key) {
                    return vm.createObject(vm.types.typeKeyword, key);
                  }));
                }
                if (command.value === "entry_key") {
                  var value = codes[1](vm, "get");
                  if (!instanceOf(value, vm.types.typeEntry)) throw "Type Error: " + value.type.value.name + " != Entry";
                  return value.value.key;
                }
                if (command.value === "entry_value") {
                  var value = codes[1](vm, "get");
                  if (!instanceOf(value, vm.types.typeEntry)) throw "Type Error: " + value.type.value.name + " != Entry";
                  return value.value.value;
                }
                if (command.value === "size") {
                  var value = codes[1](vm, "get");
                  return vm.createObject(vm.types.typeNumber, unpackVector(value).length);
                }
                if (command.value === "li") {
                  var array = [];
                  for (var i = 1; i < codes.length; i++) {
                    array.push(codes[i](vm, "get"));
                  }
                  return packVector(array);
                }
                if (command.value === "array") {
                  var array = [];
                  for (var i = 1; i < codes.length; i++) {
                    array.push(codes[i](vm, "get"));
                  }
                  return vm.createObject(vm.types.typeArray, unpackVector(packVector(array)));
                }
                if (command.value === "throw") {
                  var i = 1, value;
                  value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;

                  if (!(value !== undefined)) throw "Illegal command argument";
                  var blessedValue = value[3](vm, "get");
                  if (!instanceOf(blessedValue, vm.types.typeString)) throw "Type Error: " + blessedValue.type.value.name + " != String";
                  value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;

                  if (value !== undefined) throw "Illegal command argument: " + value[0];

                  // parse end

                  throw blessedValue.value;
                }
                if (command.value === "try") {
                  var i = 1, value;
                  value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;

                  if (!(value !== undefined && value[0] === "curly")) throw "Illegal command argument";
                  var codeTry = value[1];
                  value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;

                  if (!(value !== undefined && value[0] === "keyword" && value[2] === "catch")) throw "Illegal command argument";
                  value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;

                  if (!(value !== undefined && value[0] === "round")) throw "Illegal command argument";
                  var blessedKeyword = value[1](vm, "arguments");
                  if (!instanceOf(blessedKeyword, vm.types.typeKeyword)) throw "Type Error: " + blessedKeyword.type.value.name + " != Keyword";
                  value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;

                  if (!(value !== undefined && value[0] === "curly")) throw "Illegal command argument";
                  var codeCatch = value[1];
                  value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;

                  if (value !== undefined) throw "Illegal command argument: " + value[0];

                  // parse end

                  var blessedResult;
                  try {
                    vm.pushFrame();
                    try {
                      blessedResult = codeTry(vm, "get");
                    } finally {
                      vm.popFrame();
                    }
                  } catch (e) {
                    if (instanceOf(e, vm.types.typeException)) {
                      vm.pushFrame();
                      vm.scope.defineOrSet(blessedKeyword.value, e);
                      try {
                        blessedResult = codeCatch(vm, "get");
                      } finally {
                        vm.popFrame();
                      }
                    } else {
                      throw e;
                    }
                  }

                  return blessedResult;
                }
                if (command.value === "class") {
                  var i = 1, value;
                  value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;

                  var blessedName;
                  var isNamed;
                  if (value !== undefined && !((value[0] === "keyword" && value[2] === "extends") || value[0] === "curly")) {
                    blessedName = value[1](vm, "get");
                    if (!instanceOf(blessedName, vm.types.typeKeyword)) throw "Type Error: " + blessedName.type.value.name + " != Keyword";
                    value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;

                    isNamed = true;
                  } else {
                    blessedName = vm.createObject(vm.types.typeKeyword, "Class" + Math.floor(Math.random() * 90000000 + 10000000));
                    isNamed = false;
                  }

                  var blessedExtends;
                  if (value !== undefined && value[0] === "keyword" && value[2] === "extends") {

                    // dummy
                    value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;

                    blessedExtends = value[1](vm, "get");
                    if (instanceOf(blessedExtends, vm.types.typeKeyword)) blessedExtends = searchVariable(["class"], blessedExtends.value);
                    if (!instanceOf(blessedExtends, vm.types.typeType)) throw "Type Error: " + blessedExtends.type.value.name + " != Type";
                    value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;

                  } else {
                    blessedExtends = vm.types.typeHash;
                  }

                  var blessedResult = createType(blessedName.value, blessedExtends, false);

                  if (value !== undefined && value[0] === "curly") {
                    vm.pushFrame();
                    vm.scope.defineOrSet("class", blessedResult);
                    vm.scope.defineOrSet("super", blessedExtends);
                    try {
                      value[1](vm, "invoke")
                    } finally {
                      vm.popFrame();
                    }
                    value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;
                  }

                  if (value !== undefined) throw "Illegal command argument: " + value[0];

                  // parse end

                  if (isNamed) vm.scope.defineOrSet("_class_" + blessedName.value, blessedResult);
                  return blessedResult;
                }
                if (command.value === "new") {
                  var i = 1, value;
                  value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;

                  var blessedType = value[1](vm, "get");
                  if (instanceOf(blessedType, vm.types.typeKeyword)) blessedType = searchVariable(["class"], blessedType.value);
                  if (!instanceOf(blessedType, vm.types.typeType)) throw "Type Error: " + blessedType.type.value.name + " != Type";
                  value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;

                  var blessedArguments = value[1](vm, "get");
                  value = codes[i] !== undefined ? codes[i](vm, "contentStatement") : undefined; i++;

                  if (value !== undefined) throw "Illegal command argument: " + value[0];

                  // parse end

                  var blessedsNew = getMethodsOfTypeTree("new", blessedType);

                  for (i = 0; i < blessedsNew.length; i++) {
                     blessedArguments = callFunction(blessedsNew[i], blessedArguments);
                  }

                  blessedArguments.type = blessedType;

                  var blessedsInit = getMethodsOfTypeTree("init", blessedType);
                  for (i = blessedsInit.length - 1; i >= 0; i--) {
                    callFunction(blessedsInit[i], blessedArguments);
                  }

                  return blessedArguments;
                }
                throw "Unknown command: " + command.value;
              }
              if (operator === "_leftAmpersand") return vm.createPointer(codes[0], vm.scope);
              if (operator === "_bracketsCurly") {
                var hash = {};
                unpackVector(callInFrame(codes[0], vm, "get")).forEach(function(item) {
                  if (instanceOf(item, vm.types.typeEntry)) {
                    hash[item.value.key.value] = item.value.value;
                    return;
                  }
                  throw "Type Error: " + item.type.value.name + " is not a Entry";
                });
                return vm.createObject(vm.types.typeHash, hash);
              }
              if (operator === "_operatorColon2") {
                var hash = codes[0](vm, "get");
                if (instanceOf(hash, vm.types.typeKeyword)) hash = searchVariable(["hash", "class"], hash.value);
                var key = codes[1](vm, "get");
                if (instanceOf(hash, vm.types.typeHash)) {
                  if (instanceOf(key, vm.types.typeString)) return getPropertyBlessed(hash.value, key.value);
                  if (instanceOf(key, vm.types.typeKeyword)) return getPropertyBlessed(hash.value, key.value);
                }
                if (instanceOf(hash, vm.types.typeType)) {
                  if (instanceOf(key, vm.types.typeString)) return getPropertyBlessed(hash.value.members, key.value);
                  if (instanceOf(key, vm.types.typeKeyword)) return getPropertyBlessed(hash.value.members, key.value);
                }
                throw "Type Error: " + hash.type.value.name + "[" + key.type.value.name + "]";
              }
              if (operator === "_operatorHash") {
                var hash = codes[0](vm, "get");
                if (instanceOf(hash, vm.types.typeKeyword)) hash = searchVariable(["class"], hash.value);
                var key = codes[1](vm, "get");
                if (instanceOf(hash, vm.types.typeType)) {
                  if (instanceOf(key, vm.types.typeString)) {
                    var value;
                    while (hash != null) {
                      value = getPropertyBlessed(hash.value.members, key.value);
                      if (!instanceOf(value, vm.types.typeUndefined)) return value;
                      hash = hash.value.supertype;
                    }
                    return vm.UNDEFINED;
                  }
                }
                throw "Type Error: " + hash.type.value.name + "[" + key.type.value.name + "]";
              }
              if (operator === "_operatorPeriod") {
                var left = codes[0](vm, "get");
                var right = codes[1](vm, "get");
                return getMethodOfBlessed(left, right);
              }
              if (operator === "_operatorColonGreater") {
                var array = unpackVector(codes[0](vm, "arguments")).map(function(item) { return item.value; });
                return vm.createFunction(array, codes[1], vm.scope);
              }
              if (operator === "_concatenate") {
                return vm.createObject(vm.types.typeString, codes.map(function(code) { return vm.toString(code(vm, "get")); }).join(""));
              }
              if (operator === "_enumerateSemicolon") {
                for (var i = 0; i < codes.length - 1; i++) {
                  codes[i](vm, "invoke");
                }
                return codes[codes.length - 1](vm, "get");
              }
              if (operator === "_operatorEqual") return codes[0](vm, "set", [codes[1](vm, "get", [])]);
              if (operator === "_rightPlus2") {
                var res = codes[0](vm, "get", []);
                codes[0](vm, "set", [vm.createObject(vm.types.typeNumber, res.value + 1)]);
                return res;
              }
              if (operator === "_rightMinus2") {
                var res = codes[0](vm, "get", []);
                codes[0](vm, "set", [vm.createObject(vm.types.typeNumber, res.value - 1)]);
                return res;
              }
              if (operator === "_operatorQuestionColon") {
                var res = codes[0](vm, "get");
                return res.value ? res : codes[1](vm, "get");
              }
              if (operator === "_operatorQuestion2") {
                var res = codes[0](vm, "get");
                return !instanceOf(res, vm.types.typeUndefined) ? res : codes[1](vm, "get");
              }
              if (operator === "_hereDocumentFunction") {
                var value = codes[0](vm, "get");
                if (instanceOf(value, vm.types.typeKeyword)) value = searchVariable(["decoration", "function"], value.value);
                if (instanceOf(value, vm.types.typeFunction)) return callFunction(value, callInFrame(function(vm, context, args) {
                  return packVector([vm.createPointer(codes[1], vm.scope), vm.createPointer(codes[2], vm.scope)]);
                }, vm, "get"));
                throw "Type Error: " + operator + "/" + value.type.value.name;
              }
              if (operator === "_leftMultibyte") {
                var value = codes[0](vm, "get");
                if (instanceOf(value, vm.types.typeKeyword)) value = searchVariable(["leftMultibyte", "multibyte", "function"], value.value);
                if (instanceOf(value, vm.types.typeFunction)) {
                  return callPointer(callFunction(value, vm.createPointer(codes[1], vm.scope)), context, args);
                }
                throw "Type Error: " + operator + "/" + value.type.value.name;
              }
              if (operator === "_operatorMultibyte") {
                var value = codes[1](vm, "get");
                if (instanceOf(value, vm.types.typeKeyword)) value = searchVariable(["operatorMultibyte", "multibyte", "function"], value.value);
                if (instanceOf(value, vm.types.typeFunction)) {
                  return callPointer(callFunction(value, packVector([vm.createPointer(codes[0], vm.scope), vm.createPointer(codes[2], vm.scope)])), context, args);
                }
                throw "Type Error: " + operator + "/" + value.type.value.name;
              }
              if (operator === "_leftWord") {
                var value = codes[0](vm, "get");
                if (instanceOf(value, vm.types.typeKeyword)) value = searchVariable(["leftWord", "word", "function"], value.value);
                if (instanceOf(value, vm.types.typeFunction)) return callFunction(value, callInFrame(function(vm, context, args) {
                  return codes[1](vm, "get");
                }, vm, "get"));
                throw "Type Error: " + operator + "/" + value.type.value.name;
              }
              if (operator === "_operatorWord") {
                var value = codes[1](vm, "get");
                if (instanceOf(value, vm.types.typeKeyword)) value = searchVariable(["operatorWord", "word", "function"], value.value);
                if (instanceOf(value, vm.types.typeFunction)) return callFunction(value, callInFrame(function(vm, context, args) {
                  return packVector([codes[0](vm, "get"), codes[2](vm, "get")]);
                }, vm, "get"));
                throw "Type Error: " + operator + "/" + value.type.value.name;
              }
              if (operator === "_rightComposite") {
                var value = codes[1](vm, "get");
                if (instanceOf(value, vm.types.typeKeyword)) value = searchVariable(["rightComposite", "composite", "function"], value.value);
                if (instanceOf(value, vm.types.typeFunction)) return callFunction(value, callInFrame(function(vm, context, args) {
                  return codes[0](vm, "get");
                }, vm, "get"));
                throw "Type Error: " + operator + "/" + value.type.value.name;
              }
              if (operator === "_operatorComposite") {
                var value = codes[1](vm, "get");
                if (instanceOf(value, vm.types.typeKeyword)) value = searchVariable(["operatorComposite", "composite", "function"], value.value);
                if (instanceOf(value, vm.types.typeFunction)) return callFunction(value, callInFrame(function(vm, context, args) {
                  return packVector([codes[0](vm, "get"), codes[2](vm, "get")]);
                }, vm, "get"));
                throw "Type Error: " + operator + "/" + value.type.value.name;
              }
            } else if (context === "set") {
              if (operator === "_leftDollar") {
                var value = args[0];
                vm.scope.setOrDefine(codes[0](vm, "get").value, value);
                return value;
              }
              if (operator === "_operatorColon2") {
                var hash = codes[0](vm, "get");
                if (instanceOf(hash, vm.types.typeKeyword)) hash = searchVariable(["hash"], hash.value);
                var key = codes[1](vm, "get");
                if (instanceOf(hash, vm.types.typeHash)) {
                  if (instanceOf(key, vm.types.typeString)) return hash.value[key.value] = args[0];
                  if (instanceOf(key, vm.types.typeKeyword)) return hash.value[key.value] = args[0];
                }
                if (instanceOf(hash, vm.types.typeType)) {
                  if (instanceOf(key, vm.types.typeString)) return hash.value.members[key.value] = args[0];
                  if (instanceOf(key, vm.types.typeKeyword)) return hash.value.members[key.value] = args[0];
                }
                throw "Type Error: " + hash.type.value.name + "[" + key.type.value.name + "]";
              }
            } else if (context === "invoke") {
              if (operator === "_bracketsCurly") {
                codes[0](vm, "invoke");
                return;
              }
              vm.callMethod(operator, codes, "get", args);
              return;
            } else if (context === "contentStatement") {
              if (operator === "_bracketsRound") return ["round", codes[0], undefined, createCodeFromMethod(operator, codes)];
              if (operator === "_bracketsSquare") return ["square", codes[0], undefined, createCodeFromMethod(operator, codes)];
              if (operator === "_bracketsCurly") return ["curly", codes[0], undefined, createCodeFromMethod(operator, codes)];
              return ["normal", createCodeFromMethod(operator, codes), undefined, createCodeFromMethod(operator, codes)];
            } else if (context === "arguments") {
              if (operator === "_leftDollar") return codes[0](vm, "arguments");
              if (operator === "_enumerateComma") return packVector(codes.map(function(code) { return code(vm, "arguments"); }));
            }

            if (operator === "_leftAsterisk") {
              var value = codes[0](vm, "get");
              if (instanceOf(value, vm.types.typePointer)) return callPointer(value, context, args);
              throw "Type Error: " + operator + "/" + value.type.value.name;
            }
            if (operator === "_ternaryQuestionColon") return codes[codes[0](vm, "get").value ? 1 : 2](vm, context, args);
            if (operator === "_bracketsRound") return callInFrame(codes[0], vm, context, args);

            throw "Unknown operator: " + operator + "/" + context;
          };
          this.toString = function(value) {
            consumeLoopCapacity();
            if (instanceOf(value, vm.types.typeValue)) {
              return "" + callMethodOfBlessed(value, vm.createObject(vm.types.typeKeyword, "toString"), vm.VOID).value;
            } else {
              return "" + value;
            }
          };
          this.toNative = function(value) {
            consumeLoopCapacity();
            var vm = this;
            if (instanceOf(value, vm.types.typeVector)) {
              return value.value.map(function(scalar) { return vm.toNative(scalar); });
            }
            if (instanceOf(value, vm.types.typeArray)) {
              return value.value.map(function(scalar) { return vm.toNative(scalar); });
            }
            return value.value;
          };
          this.toBoolean = function(value) {
            consumeLoopCapacity();
            return !!value.value;
          };
          this.createLiteral = function(type, value, context, args) {
            consumeLoopCapacity();
            if (context === "get") {
              if (type === "Integer") return vm.createObject(vm.types.typeNumber, value);
              if (type === "Float") return vm.createObject(vm.types.typeNumber, value);
              if (type === "String") return vm.createObject(vm.types.typeString, value);
              if (type === "Identifier") {
                if (value === "true") return vm.TRUE;
                if (value === "false") return vm.FALSE;
                if (value === "undefined") return vm.UNDEFINED;
                if (value === "null") return vm.NULL;
                if (value === "Infinity") return vm.createObject(vm.types.typeNumber, Infinity);
                if (value === "NaN") return vm.createObject(vm.types.typeNumber, NaN);
                return vm.createObject(vm.types.typeKeyword, value);
              }
              if (type === "Void") return vm.VOID;
              if (type === "Boolean") return vm.getBoolean(value);
            } else if (context === "invoke") {
              return vm.createLiteral(type, value, "get", []);
            } else if (context === "contentStatement") {
              if (type === "Identifier") return ["keyword", createCodeFromLiteral(type, value), value, createCodeFromLiteral(type, value)];
              return ["normal", createCodeFromLiteral(type, value), undefined, createCodeFromLiteral(type, value)];
            } else if (context === "arguments") {
              if (type === "Identifier") return vm.createObject(vm.types.typeKeyword, value);
              if (type === "Void") return vm.VOID;
            }
            throw "Unknown Literal Type: " + context + "/" + type;
          };
        }
        VMStandard.prototype.pushScope = function() {
          this.scope = new Scope(this.scope, false, this.UNDEFINED);
        };
        VMStandard.prototype.pushFrame = function() {
          this.scope = new Scope(this.scope, true, this.UNDEFINED);
        };
        VMStandard.prototype.popFrame = function() {
          this.scope = this.scope.getParentFrame();
        };
        VMStandard.prototype.pushStack = function(scope2) {
          this.stack.push(this.scope);
          this.scope = scope2;
        };
        VMStandard.prototype.popStack = function() {
          this.scope = this.stack.pop();
        };

        VMStandard.prototype.createObject = function(type, value) {
          return {
            type: type,
            value: value,
          };
        };
        VMStandard.prototype.getBoolean = function(value) {
          return value ? this.TRUE : this.FALSE;
        };
        VMStandard.prototype.createException = function(message) {
          return this.createObject(this.types.typeException, {
            message: message,
          });
        };
        VMStandard.prototype.createFunction = function(args, code, scope) {
          return this.createObject(this.types.typeFunction, {
            args: args,
            code: code,
            scope: scope,
          });
        };
        VMStandard.prototype.createPointer = function(code, scope) {
          return this.createObject(this.types.typePointer, {
            code: code,
            scope: scope,
          });
        };

        return VMStandard;
      })();
    } else {
      throw "Unknown VM name: " + name;
    }
  }

}

ExpressionPlain
  = main:Expression {
      var vm = new (getVM("standard"))();
      var texts = [main[0]];
      var i;
      for (i = 1; i < main.length; i += 2) {
        try {
          texts.push(vm.toString(main[i][1](vm, "get")));
        } catch (e) {
          try {
            texts.push("[Error: " + vm.toString(e) + "][" + main[i][0] + "]");
          } catch (e) {
            texts.push("[Error: " + e + "][" + main[i][0] + "]");
          }
        }
        texts.push(main[i + 1]);
      }
      return texts.join("");
    }

VMFactory
  = name:([a-zA-Z0-9_]+ { return text(); }) { return getVM(name); }

Expression
  = Message

Message
  = ("#!" [^\n\r]* ([\r\n] / "\r\n"))? head:MessageText tail:("\\" _ MessageFormula _ "\\" MessageText)* {
      var result = [head], i;

      for (i = 0; i < tail.length; i++) {
        result.push(tail[i][2]);
        result.push(tail[i][5]);
      }

      return result;
    }

MessageText
  = main:(
      [^\\]
    / "\\\\" { return "\\"; }
    )* { return main.join(""); }

MessageFormula
  = main:Formula {
      return [text(), main];
    }

Formula
  = Line

Line
  = head:Arrows tail:(_ (";") _ Arrows)* (_ ";")? { return enumerate(head, tail, "Semicolon"); }

Arrows
  = head:(
      (
        main:Vector _ "-->" _ { return ["Minus2Greater", main]; }
      / main:Vector _ "->" _ { return ["MinusGreater", main]; }
      / main:Vector _ "==>" _ { return ["Equal2Greater", main]; }
      / main:Vector _ "=>" _ { return ["EqualGreater", main]; }
      )+
    / main:Vector _ ":>" _ { return [["ColonGreater", main]]; }
    / main:Vector _ "=" _ { return [["Equal", main]]; }
    )* tail:Vector {
      var result = tail, i, j;
      for (i = head.length - 1; i >= 0; i--) {
        var result2 = head[i][0][1];
        for (j = 1; j < head[i].length; j++) {
          result2 = createCodeFromMethod("_operator" + head[i][j - 1][0], [result2, head[i][j][1]]);
        }
        result = createCodeFromMethod("_operator" + head[i][head[i].length - 1][0], [result2, result]);
      }
      return result;
    }

Vector
  = head:Entry tail:(_ (",") _ Entry)* (_ ",")? { return enumerate(head, tail, "Comma"); }

Entry
  = head:Iif tail:(_ (
      ":" { return "Colon"; }
    ) _ Iif)* { return operatorLeft(head, tail); }

Iif
  = head:Range _ "?" _ body:Iif _ ":" _ tail:Iif { return createCodeFromMethod("_ternaryQuestionColon", [head, body, tail]); }
  / head:Range _ "?:" _ tail:Iif { return createCodeFromMethod("_operatorQuestionColon", [head, tail]); }
  / head:Range _ "??" _ tail:Iif { return createCodeFromMethod("_operatorQuestion2", [head, tail]); }
  / Range

Range
  = head:Or tail:(_ (
      "~" { return "Tilde"; }
    / ".." { return "Period2"; }
    ) _ Or)* { return operatorLeft(head, tail); }

Or
  = head:And tail:(_ (
      "||" { return "Pipe2"; }
    / "|" { return "Pipe"; }
    ) _ And)* { return operatorLeft(head, tail); }

And
  = head:Compare tail:(_ (
      "&&" { return "Ampersand2"; }
    / "&" { return "Ampersand"; }
    ) _ Compare)* { return operatorLeft(head, tail); }

Compare
  = head:Shift tail:(_ (
      ">=" { return "GreaterEqual"; }
    / ">" { return "Greater"; }
    / "<=" { return "LessEqual"; }
    / "<" { return "Less"; }
    / "!=" { return "ExclamationEqual"; }
    / "==" { return "Equal2"; }
    ) _ Shift)* {
      if (tail.length == 0) return head;
      var codes = [], left = head, right, i;

      for (i = 0; i < tail.length; i++) {
        right = tail[i][3];
        codes.push(createCodeFromMethod("_operator" + tail[i][1], [left, right]));
        left = right;
      }

      return function(vm, context, args) {
        if (context === "get") {
          var array = codes.map(function(code) { return code(vm, "get"); });

          for (var i = 0; i < array.length; i++) {
            if (!vm.toBoolean(array[i])) return vm.createLiteral("Boolean", false, context, args);
          }

          return vm.createLiteral("Boolean", true, context, args);
        } else {
          throw "Unknown context: " + context;
        }
      };
    }

Shift
  = head:Add tail:(_ (
      "<<" { return "Less2"; }
    / ">>" { return "Grater2"; }
    ) _ Term)* { return operatorLeft(head, tail); }

Add
  = head:Term tail:(_ (
      "+" { return "Plus"; }
    / "-" { return "Minus"; }
    ) _ Term)* { return operatorLeft(head, tail); }

Term
  = head:Power tail:(_ (
      "*" { return "Asterisk"; }
    / "/" { return "Slash"; }
    / "%" { return "Percent"; }
    ) _ Power)* { return operatorLeft(head, tail); }

Power
  = head:(MultibyteOperating _ (
      "^" { return "Caret"; }
    ) _)* tail:MultibyteOperating { return operatorRight(head, tail); }

MultibyteOperating
  = head:Left tail:(_ (
      CharacterMultibyteSymbol { return ["Multibyte", createCodeFromLiteral("Identifier", text())]; }
    / "`" _ main:Formula _ "`" { return ["Word", main]; }
    ) _ Left)* { return operatorLeft(head, tail); }

Left
  = head:((
      "+" { return "Plus"; }
    / "-" { return "Minus"; }
    / "@" { return "Atsign"; }
    / "&" { return "Ampersand"; }
    / "*" { return "Asterisk"; }
    / "!" { return "Exclamation"; }
    / "~" { return "Tilde"; }
    / CharacterMultibyteSymbol { return ["Multibyte", createCodeFromLiteral("Identifier", text())]; }
    / "`" _ main:Formula _ "`" { return ["Word", main]; }
    ) _)* tail:Right { return left(head, tail); }

Right
  = head:Variable tail:(_ (
      "(" _ main:Formula _ ")" { return ["_rightbracketsRound", [main]]; }
    / "[" _ main:Formula _ "]" { return ["_rightbracketsSquare", [main]]; }
    / "{" _ main:Formula _ "}" { return ["_rightbracketsCurly", [main]]; }
    / "(" _ ")" { return ["_rightbracketsRound", [createCodeFromLiteral("Void", "void")]]; }
    / "[" _ "]" { return ["_rightbracketsSquare", [createCodeFromLiteral("Void", "void")]]; }
    / "{" _ "}" { return ["_rightbracketsCurly", [createCodeFromLiteral("Void", "void")]]; }
    / "::" _ main:Variable { return ["_operatorColon2", [main]]; }
    / "." _ main:Variable { return ["_operatorPeriod", [main]]; }
    / "#" _ main:Variable { return ["_operatorHash", [main]]; }
    / "++" { return ["_rightPlus2", []]; }
    / "--" (! ">") { return ["_rightMinus2", []]; }
    ))* { return right(head, tail); }

Variable
  = head:((
      "$" { return "Dollar"; }
    ) _)* tail:Factor { return left(head, tail); }

Factor
  = "(" _ main:Formula _ ")" { return createCodeFromMethod("_bracketsRound", [main]); }
  / "[" _ main:Formula _ "]" { return createCodeFromMethod("_bracketsSquare", [main]); }
  / "{" _ main:Formula _ "}" { return createCodeFromMethod("_bracketsCurly", [main]); }
  / "(" _ ")" { return createCodeFromMethod("_bracketsRound", [createCodeFromLiteral("Void", "void")]); }
  / "[" _ "]" { return createCodeFromMethod("_bracketsSquare", [createCodeFromLiteral("Void", "void")]); }
  / "{" _ "}" { return createCodeFromMethod("_bracketsCurly", [createCodeFromLiteral("Void", "void")]); }
  / Composite
  / Identifier
  / String
  / StringReplaceable
  / HereDocument
  / Statement

Statement
  = "/" head:Identifier main:(_ ContentStatement)* (_ "/" (! Identifier))? {
      var array = [head];
      main.map(function(item) { array.push(item[1]); })
      return createCodeFromMethod("_statement", array);
    }

ContentStatement
  = head:FactorStatement tail:(_ (",") _ FactorStatement)* { return enumerate(head, tail, "Comma"); }
  / Statement

FactorStatement
  = head:Variable tail:(_ (
      "::" _ main:Variable { return ["_operatorColon2", [main]]; }
    / "." _ main:Variable { return ["_operatorPeriod", [main]]; }
    / "#" _ main:Variable { return ["_operatorHash", [main]]; }
    ))* { return right(head, tail); }

Composite
  = head:Number body:BodyComposite tail:Composite { return createCodeFromMethod("_operatorComposite", [head, body, tail]); }
  / head:Number body:BodyComposite { return createCodeFromMethod("_rightComposite", [head, body]); }
  / head:Number { return head; }

Number
  = Float
  / Hex
  / Integer

Float "Float"
  = [0-9]+ ("." [0-9]+)? [eE] [+-]? [0-9]+ { return createCodeFromLiteral("Float", parseFloat(text())); }
  / [0-9]+ "." [0-9]+ { return createCodeFromLiteral("Float", parseFloat(text())); }

Integer "Integer"
  = [0-9]+ { return createCodeFromLiteral("Integer", parseInt(text(), 10)); }

Hex "Hex"
  = "0x" main:([0-9a-zA-Z]+ { return text(); }) { return createCodeFromLiteral("Integer", parseInt(main, 16)); }

BodyComposite
  = CharacterIdentifier+ { return createCodeFromLiteral("Identifier", text()); }

Identifier "Identifier"
  = CharacterIdentifier ([0-9] / CharacterIdentifier)* { return createCodeFromLiteral("Identifier", text()); }

String
  = "'" main:ContentString* "'" { return createCodeFromLiteral("String", main.join("")); }

ContentString
  = "\\\\" { return "\\"; }
  / "\\\"" { return "\""; }
  / "\\'" { return "'"; }
  / "\\$" { return "$"; }
  / "\\r" { return "\r"; }
  / "\\n" { return "\n"; }
  / "\\t" { return "\t"; }
  / "\\x" main:([a-zA-Z0-9][a-zA-Z0-9] { return text(); }) { return String.fromCharCode(parseInt(main, 16)); }
  / "\\u" main:([a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9] { return text(); }) { return String.fromCharCode(parseInt(main, 16)); }
  / [^'\\]

StringReplaceable
  = "\"" main:ContentStringReplaceable "\"" { return main; }

ContentStringReplaceable
  = head:ContentStringReplaceableText tail:(ContentStringReplaceableReplacement ContentStringReplaceableText)* {
      var codes = [head];
      var i;
      for (i = 0; i < tail.length; i++) {
        codes.push(tail[i][0]);
        codes.push(tail[i][1]);
      }
      return createCodeFromMethod("_concatenate", codes);
    }

ContentStringReplaceableText
  = main:(
      "\\\\" { return "\\"; }
    / "\\\"" { return "\""; }
    / "\\'" { return "'"; }
    / "\\$" { return "$"; }
    / "\\r" { return "\r"; }
    / "\\n" { return "\n"; }
    / "\\t" { return "\t"; }
    / "\\x" main:([a-zA-Z0-9][a-zA-Z0-9] { return text(); }) { return String.fromCharCode(parseInt(main, 16)); }
    / "\\u" main:([a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9] { return text(); }) { return String.fromCharCode(parseInt(main, 16)); }
    / [^"$\\]
    )* { return createCodeFromLiteral("String", main.join("")); }

ContentStringReplaceableReplacement
  = "$" "(" main:Formula ")" { return main; }
  / "$" "{" main:Formula "}" { return createCodeFromMethod("_leftDollar", [main]); }
  / "$" main:(Integer / Identifier) { return createCodeFromMethod("_leftDollar", [main]); }

HereDocument
  = "%" head:(
      head:Identifier "(" _ tail:Formula _ ")" { return [head, tail]; }
    / head:Identifier "(" _ ")" { return [head, createCodeFromLiteral("Void", "void")]; }
    )? tail:(
      ";" { return createCodeFromLiteral("Void", "void"); }
    / (
        begin:HereDocumentDelimiter main:(
          "{" main:(

            main:(! ("}" end:HereDocumentDelimiter & { return begin === end; }) main:(
              "%%" { return "%"; }
            / [^%]
            ) { return main; })+ { return createCodeFromLiteral("String", main.join("")); }
          / HereDocument

          )* "}" { return createCodeFromMethod("_concatenate", main); }
        / "[" main:(

            main:(! ("]" end:HereDocumentDelimiter & { return begin === end; }) main:(
              .
            ) { return main; })+ { return createCodeFromLiteral("String", main.join("")); }

          )* "]" { return createCodeFromMethod("_concatenate", main); }
        / begin2:HereDocumentDelimiter2 main:(

            main:(! (end2:HereDocumentDelimiter2 end:HereDocumentDelimiter & { return begin2 === end2 && begin === end; }) main:(
              .
            ) { return main; })+ { return createCodeFromLiteral("String", main.join("")); }

          )* HereDocumentDelimiter2 { return createCodeFromMethod("_concatenate", main); }
        ) HereDocumentDelimiter { return main; }
      / (
          "{" main:(

            main:(! ("}") main:(
              "%%" { return "%"; }
            / [^%]
            ) { return main; })+ { return createCodeFromLiteral("String", main.join("")); }
          / HereDocument

          )* "}" { return createCodeFromMethod("_concatenate", main); }
        / "[" main:(

            main:(! ("]") main:(
              .
            ) { return main; })+ { return createCodeFromLiteral("String", main.join("")); }

          )* "]" { return createCodeFromMethod("_concatenate", main); }
        / begin2:HereDocumentDelimiter2 main:(

            main:(! (end2:HereDocumentDelimiter2 & { return begin2 === end2; }) main:(
              .
            ) { return main; })+ { return createCodeFromLiteral("String", main.join("")); }

          )* HereDocumentDelimiter2 { return createCodeFromMethod("_concatenate", main); }
        )
      )
    ) {
      if (head !== null) {
        return createCodeFromMethod("_hereDocumentFunction", [head[0], head[1], tail]);
      } else {
        return tail;
      }
    }
  / "%" head:(
      "(" _ tail:Formula _ ")" { return tail; }
    / "(" _ ")" { return createCodeFromLiteral("Void", "void"); }
    ) {
      return head;
    }

HereDocumentDelimiter
  = CharacterIdentifier+ { return text(); }

HereDocumentDelimiter2
  = [!"#$%&'*+,\-./:=?@\\^_`|~] { return text(); }

_ "Comments"
  = (
      "/*" ((! "*/") .)* "*/"
    / CommentBlockNested
    / "//" [^\n\r]*
    / "#!" [^\n\r]*
    / CharacterBlank+
    )*

CommentBlockNested
  = "/+" (
      (! ("/+" / "+/")) .
    / CommentBlockNested
    )* "+/"

CharacterMultibyteSymbol
  = CharacterSurrogates
  / (! (CharacterSymbol / CharacterNumber / CharacterIdentifier / CharacterBlank / CharacterContectSurrogates)) .

CharacterSymbol
  = (! (CharacterNumber / CharacterAlphabet / CharacterSymbolIdentifier)) [!-~]

CharacterIdentifier
  = CharacterAlphabet
  / CharacterSymbolIdentifier
  / CharacterHiragana
  / CharacterKatakana
  / CharacterCJKUnifiedIdeographsExtensionA
  / CharacterCJKUnifiedIdeographs

CharacterNumber
  = [0-9]

CharacterAlphabet
  = [a-zA-Z]

CharacterSymbolIdentifier
  = [_]

CharacterHiragana
  = [\u3040-\u309F]

CharacterKatakana
  = [\u30A0-\u30FF]

CharacterCJKUnifiedIdeographsExtensionA
  = [\u3400-\u4DBF]

CharacterCJKUnifiedIdeographs
  = [\u4E00-\u9FFF]

CharacterSurrogates
  = CharacterContectSurrogates CharacterContectSurrogates { return text(); }

CharacterContectSurrogates
  = [\uD800-\uDBFF\uDC00-\uDFFF]

CharacterBlank
  = [ \t\n\r　]
