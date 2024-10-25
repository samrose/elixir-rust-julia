use rustler::NifResult;
use jlrs::prelude::*;
use std::sync::Once;

static INIT: Once = Once::new();
static mut JULIA: Option<(&'static Julia, &'static JoinHandle<()>)> = None;

fn init_julia() -> Result<&'static Julia, JlrsError> {
    unsafe {
        INIT.call_once(|| {
            let (julia, handle) = Builder::new()
                .async_runtime(Tokio::<1>::new(false))
                .spawn()
                .expect("Could not start Julia");
            JULIA = Some((Box::leak(Box::new(julia)), Box::leak(Box::new(handle))));
        });
        Ok(JULIA.unwrap().0)
    }
}

#[rustler::nif]
fn add(a: f64, b: f64) -> NifResult<f64> {
    let julia = init_julia()
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
        
    unsafe {
        julia.scope(|frame| {
            frame.eval::<f64>(&format!("{}+{}", a, b))
        })
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))
    }
}

#[rustler::nif]
fn multiply_array(arr: Vec<f64>) -> NifResult<f64> {
    let julia = init_julia()
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
        
    unsafe {
        julia.scope(|frame| {
            let arr_str = arr.iter()
                .map(|x| x.to_string())
                .collect::<Vec<_>>()
                .join(",");
            frame.eval::<f64>(&format!("prod([{}])", arr_str))
        })
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))
    }
}

rustler::init!("Elixir.JuliaBridge");
