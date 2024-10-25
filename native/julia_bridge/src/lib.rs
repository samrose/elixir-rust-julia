use jlrs::prelude::*;
use jlrs::runtime::handle::local_handle::LocalHandle;
use rustler::{NifResult, Env, Error};
use std::thread_local;

thread_local! {
    static RUNTIME: std::cell::RefCell<Option<LocalHandle>> = std::cell::RefCell::new(None);
}

fn get_or_init_runtime() -> Result<LocalHandle, Error> {
    RUNTIME.with(|rt| {
        let mut rt = rt.borrow_mut();
        if rt.is_none() {
            let handle = Builder::new()
                .n_threads(1)
                .start_local()
                .map_err(|_| Error::Term(Box::new(atoms::error())))?;
            *rt = Some(handle);
        }
        Ok(rt.as_ref().unwrap().clone())
    })
}

#[rustler::nif]
fn call_julia_function(env: Env, func_name: String, args: Vec<f64>) -> NifResult<f64> {
    let runtime = get_or_init_runtime()?;
    
    runtime.local_scope::<_, 2>(|mut frame| {
        unsafe {
            // First check if calculator.jl needs to be included
            if !Value::eval_string::<bool>(&mut frame, "@isdefined(add)")
                .map_err(|_| Error::Term(Box::new(atoms::error())))? {
                runtime.include("calculator.jl")
                    .map_err(|_| Error::Term(Box::new(atoms::error())))?;
            }

            // Get the function
            let func = Value::eval_string::<Value>(&mut frame, &func_name)
                .map_err(|_| Error::Term(Box::new(atoms::error())))?;
            
            // Convert arguments
            let julia_args: Vec<Value> = args.iter()
                .map(|&x| Value::new(&mut frame, x))
                .collect();
            
            // Call function and convert result
            let result = func.call(&julia_args)
                .map_err(|_| Error::Term(Box::new(atoms::error())))?;
            
            result.unbox::<f64>()
                .map_err(|_| Error::Term(Box::new(atoms::error())))
        }
    })
}

mod atoms {
    rustler::atoms! {
        error
    }
}

rustler::init!("Elixir.JuliaBridge");
