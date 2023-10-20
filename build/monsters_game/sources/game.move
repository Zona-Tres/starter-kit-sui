module monsters_game::game {
	
	// --------------------------------- Importacion de modulos -----------------------------------
	use std::string::{String, utf8};
	use std::option::{Self, Option};

	use sui::object::{Self, UID};
	use sui::transfer;
	use sui::sui::SUI;
	use sui::balance::{Self, Balance};
	use sui::coin::{Self, Coin};
	use sui::tx_context::{Self, TxContext};


	// -------------------------------- CONSTANTES ----------------------------------------
	const MIN_FEE: u64 = 1000;
	// ------------------------------------------------------------------------------------

	// Es un tipo que se define que el owner de este asset podra realizar o invocar funciones que requieran un rol de admin
	// Al momento de inicializar el Move package dentro de la funcion init es normal transferir este asset al address admin
	// esto es llamado tambien patron de capacidad o Capability Pattern
	struct AdminCap has key {
		id: UID
	}

	//objeto que representa un item dentro de mi monstruo 
	struct Armadura has key, store {
		id: UID,
		bono_velocidad: u8,
		bono_defensa: u8,
	}

	// Objeto tipo NFT llamado Sui Object el cual es almacenado en el sui global storage
	// Las Abilities "key" "store" lo identifican como un objeto dandole un id y la funcionalidad de ser almacenado en el object storage
	struct Monster has key, store{
		id: UID,
		nombre: String,
		rareza: u8,
		ataque: u8,
		defensa: u8,
		velocidad: u8,
		armadura: Option<Armadura>
		
	}
	
	// creamos un wrapping object este empaquetara nuestro objeto principal en un objeto que podremos transferir
	// utilizar y desechar, este puede servir en un swap en donde compartimos dos objetos 
	struct WrappingMonster has key {
		id: UID,
		original_owner: address,
		monstruo_intercambio: Monster,
		fee: Balance<SUI>,
	}
	
	// Funcion de inicializacion, esta se llama una unica vez al publicar el contrato 
	// Aqui se crea la instancia del asset "AdminCap" y se le da el owner a la address correspondiente
	fun init (ctx: &mut TxContext) {
		transfer::transfer(AdminCap {id: object::new(ctx)}, tx_context::sender(ctx))
	}


	// --------------------------- FUNCIONES -----------------------------------

	// Esta funcion actua como un minter o creador de monstruos utilizando el patron de capability, este hace que solo
	// el address que contenga el objeto admnistrador definido en  el objeto adminCap pueda ejecutar este metodo.
	public entry fun crear_monstruo(_: &AdminCap, to: address, nombre: String, rareza: u8, ataque: u8, defensa: u8, velocidad: u8, ctx: &mut TxContext){
		//creamos el Monstruo
		let monstruo = Monster {
			id: object::new(ctx),
			nombre: nombre,
			rareza: rareza,
			ataque: ataque,
			defensa: defensa,
			velocidad: velocidad,
			armadura: option::none(),
		};
		//transferimos el monstruo
		transfer::transfer(monstruo, to);

	}		

	// creamos un objeto armadura para poder anadirlo dentro del objeto Monstruo como un objeto anidado o empaquetado
	public entry fun crear_armadura(bono_velocidad: u8, bono_defensa: u8, ctx: &mut TxContext) {
		let armadura = Armadura {
			id: object::new(ctx),
			bono_velocidad: bono_velocidad,
			bono_defensa: bono_defensa,
		};
		transfer::transfer(armadura, tx_context::sender(ctx));
	}

	public entry fun equipar_armadura(monstruo: &mut Monster, armadura: Armadura, ctx: &mut TxContext) {
		if(option::is_some(&monstruo.armadura)) {
			// sacamos del objeto monstruo su armadura para transferirlo a mi address
			let armadura_vieja = option::extract(&mut monstruo.armadura);
			transfer::transfer(armadura_vieja, tx_context::sender(ctx));
		};
		// le mandamos el nuevo objeto armadura al monstruo
		option::fill(&mut monstruo.armadura, armadura);
	}

	// ------------------------------ RUTINA DE INTERCAMBIO ---------------------------------
	// Creamos una funcion para intercabiar monstruos (swap) mediante el uso de un wrapping object
	public entry fun pedir_intercambio(monstruo: Monster, fee: Coin<SUI>, service_address: address, ctx: &mut TxContext) {

		//evaluamos que el fee que se mande sea el minimo y si no ocurre un aborto en la ejecucion
		assert!(coin::value(&fee) >= MIN_FEE, 0);

		// Creamos el wrapping object, con esto el objeto monster pierde su id y se vuelve parte de WrappingMonster
		let wrapper = WrappingMonster {
			id: object::new(ctx),
			original_owner: tx_context::sender(ctx),
			monstruo_intercambio: monstruo,
			// destructura el objeto coin y solo nos quedamos con el balance
			fee: coin::into_balance(fee),
		};
		// transferimos el objeto empaquetado a quien hara de swap service y el sera quien ejecute la funcion
		transfer::transfer(wrapper, service_address);
	}

	// cuando el servicio de swap de monstruos tenga mas de 2 monstruos podra llamar a la funcion de efectuar 
	// el intercambio por monstruos de igual rareza y recibir un fee
	public entry fun ejecutar_intercambio(wrapper_monstruo1: WrappingMonster, wrapper_monstruo2: WrappingMonster, ctx: &mut TxContext) {
		// nos aseguramos de que la rareza de ambos sea igual 
		assert!(wrapper_monstruo1.monstruo_intercambio.rareza == wrapper_monstruo2.monstruo_intercambio.rareza, 0);

		//desempaquetamos los objetos y con ello traemos de vuelta al objeto Monster como un objeto en sui con su id 
		let WrappingMonster {
			id: id1,
			original_owner: original_owner1,
			monstruo_intercambio: monstruo1,
			fee: fee1,
		} = wrapper_monstruo1;

		let WrappingMonster {
			id: id2,
			original_owner: original_owner2,
			monstruo_intercambio: monstruo2,
			fee: fee2,
		} = wrapper_monstruo2;
	
		// llevamos a cabo el intercambio de los objetos a sus nuevos owners
        transfer::transfer(monstruo1, original_owner2);
        transfer::transfer(monstruo2, original_owner1);

        // Quien presto el servicio recibe su fee
        let service_address = tx_context::sender(ctx);
		// balance es un modulo que permite manejar tokens, este es usado en el modulo coin para todo lo referente a balance
		// esto une los dos balances en uno solo, fee1 (fucniona como un acumulador self.value + value)
        balance::join(&mut fee1, fee2);
		// al momento de enviar un token fungible debera hacerse como objeto con la funcion from_balance
        transfer::public_transfer(coin::from_balance(fee1, ctx), service_address);

        // Una vez desempaquetados los objetos y transferidos el WrappingMonster object debera ser eliminado.
		// esto puede verse como un pan en una bolsa, una vez tu como dueno de ese pan abre la bolsa y lo toma
		// no necesitamos la bolsa
        object::delete(id1);
        object::delete(id2);
	}

	
	// ------------------------------ FIN DE LA RUTINA DE INTERCAMBIO ----------------------


	// ------------------------------- CONSULTAR PROPIEDADES --------------------------------------

	// leer una propiedad de un objeto
	public fun ver_ataque(monstruo: &Monster): u8 {
		monstruo.ataque
	}

	// escribir una propiedad de un objeto
	public entry fun aumentar_ataque (monstruo: &mut Monster, incremento: u8) {
		monstruo.ataque = monstruo.ataque + incremento
	}

	
}
