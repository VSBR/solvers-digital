#include <v8.h>
#include <node.h>
#include <vector>
#include <string>
#include <cstring>
#include <iostream>
#include <cstdlib>
#include "sass_context_wrapper.h"

using namespace v8;
using namespace std;

vector<string> sass_custom_function_names;
const char* sass_custom_function(const char* name, const char* args);
Local<Function> sass_custom_function_js;

Handle<Value> RenderFileSync(const Arguments& args) {
    HandleScope scope;
    if (args.Length() < 6) {
      Local<String> error = String::New("function RenderFileSync takes 6 arguments;");
      ThrowException(Exception::Error(error));
      return scope.Close(Undefined());
    }
    if (!args[0]->IsString()) {
      Local<String> error = String::New("arguments[0] must be string");
      ThrowException(Exception::Error(error));
      return scope.Close(Undefined());
    }
    if (!args[1]->IsString()) {
      Local<String> error = String::New("arguments[1] must be string");
      ThrowException(Exception::Error(error));
      return scope.Close(Undefined());
    }
    if (!args[4]->IsFunction()) {
      Local<String> error = String::New("arguments[4] must be function");
      ThrowException(Exception::Error(error));
      return scope.Close(Undefined());
    }
    sass_file_context* ctx = sass_new_file_context();
    char *filename;
    String::AsciiValue astr(args[0]);
    String::AsciiValue bstr(args[1]);

    filename = new char[strlen(*astr)+1];
    strcpy(filename, *astr);
    ctx->input_path = filename;
    ctx->options.include_paths = new char[strlen(*bstr)+1];
    strcpy(ctx->options.include_paths, *bstr);
    ctx->options.image_path = new char[0];
    ctx->options.output_style = args[2]->Int32Value();
    ctx->options.source_comments = args[3]->Int32Value();

    sass_custom_function_js = Local<Function>::Cast(args[4]);
    ctx->custom_function = sass_custom_function;
    Local<Array> arr = Local<Array>::Cast(args[5]);
    int len = arr->Length();
    sass_custom_function_names.clear();
    const char** c_arr_str = NULL;
    if (len > 0) {
      c_arr_str = (const char**)malloc(sizeof(const char**) * len);
      for (int i=0; i < len; i++) {
        String::AsciiValue func_name(arr->Get(i));
        sass_custom_function_names.push_back(*func_name);
        c_arr_str[i] = sass_custom_function_names[i].c_str();
      }
      ctx->custom_function_names = c_arr_str;
      ctx->num_custom_functions = len;
    }

    sass_compile_file(ctx);

    filename = NULL;
    delete ctx->input_path;
    ctx->input_path = NULL;
    delete ctx->options.include_paths;
    ctx->options.include_paths = NULL;
    delete ctx->options.image_path;
    ctx->options.image_path = NULL;

    if (ctx->error_status == 0) {
        Local<Value> output = Local<Value>::New(String::New(ctx->output_string));
        sass_free_file_context(ctx);
        if (len > 0) {
          free(c_arr_str);
        }

        return scope.Close(output);
    }
    Local<String> error = String::New(ctx->error_message);
    sass_free_file_context(ctx);

    ThrowException(Exception::Error(error));
    return scope.Close(Undefined());
}

static string js_result;
const char* sass_custom_function(const char* name, const char* args) {
  // std::cout << "[" << name << "]" << std::endl;
  char* c_str;
  // std::cout << args << std::endl;
  Local<Value> argv[] = {
    String::New(name),
    String::New(args)
  };
  Local<Value> result = sass_custom_function_js->Call(Context::GetCurrent()->Global(), 2, argv);
  if (!result->IsString()) {
    Local<String> error = String::New("return value must be string");
    ThrowException(Exception::Error(error));
    return "null";
  }
  String::AsciiValue result_str(result);
  int len = strlen(*result_str);
  if (len == 0) {
    Local<String> error = String::New("return value must be string");
    ThrowException(Exception::Error(error));
    return "null";
  }
  c_str = new char[len+1];
  strcpy(c_str, *result_str);
  // std::cout << ">>" << c_str << std::endl;
  return (const char*)c_str;
}

void RegisterModule(v8::Handle<v8::Object> target) {
    NODE_SET_METHOD(target, "renderFileSync", RenderFileSync);
}

NODE_MODULE(binding, RegisterModule);
