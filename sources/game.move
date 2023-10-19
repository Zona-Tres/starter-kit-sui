module monsters_game::game {
	
	// --------------------------------- Importacion de modulos -----------------------------------
	use std::string::{String, utf8};
	use sui::object::{Self, UID};
	use sui::transfer;
	use sui::tx_context::{Self, TxContext};
	use sui::math;

	// Es un tipo que se define que el owner de este asset podra realizar o invocar funciones que requieran un rol de admin
	// Al momento de inicializar el Move package dentro de la funcion init es normal transferir este asset al address admin
	// esto es llamado tambien patron de capacidad o Capability Pattern
	struct AdminCap has key {
		id: UID
	}

	// Objeto tipo NFT llamado Sui Object el cual es almacenado en el sui global storage
	// Las Abilities "key" "store" lo identifican como un objeto dandole un id y la funcionalidad de ser almacenado en el object storage
	struct Monster has key, store{
		id: UID,
		nombre: String,
		ataque: u8,
		defensa: u8,
		velocidad: u8,
	}
	
	// Funcion de inicializacion, esta se llama una unica vez al publicar el contrato 
	// Aqui se crea la instancia del asset "AdminCap" y se le da el owner a la address correspondiente
	fun init (ctx: &mut TxContext) {
		transfer::transfer(AdminCap {id: object::new(ctx)}, tx_context::sender(ctx))
	}


	// --------------------------- FUNCIONES -----------------------------------

	public entry fun crear_monstruo(_: &AdminCap, to: address, nombre: String, ataque: u8, defensa: u8, velocidad: u8, ctx: &mut TxContext){
		let monstruo = Monster {
			id: object::new(ctx),
			nombre: nombre,
			ataque: ataque,
			defensa: defensa,
			velocidad: velocidad
		};
		transfer::transfer(monstruo, to);

	}		

	// leer
	public fun ver_ataque(monstruo: &Monster): u8 {
		monstruo.ataque
	}

	public entry fun aumentar_ataque (monstruo: &mut Monster, incremento: u8) {
		monstruo.ataque = monstruo.ataque + incremento
	}

	public entry fun dejar_en_libertad(monstruo: Monster) {
		let Monster {id, nombre:_, ataque:_, defensa:_, velocidad:_} = monstruo;
		object::delete(id);
	}

	
}
