/// Module: admin
module auction::admin;

public struct AdminCap has key {
    id: UID,
}

fun init(ctx: &mut TxContext) {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };

    transfer::transfer(admin_cap, ctx.sender());
}