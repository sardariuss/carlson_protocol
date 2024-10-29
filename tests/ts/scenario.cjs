// Load environment variables from .env file
require('dotenv').config({ path: '../../.env' });

const { getActor } = require("./actor.cjs");
const { toNs } = require("./duration.cjs");
const { Ed25519KeyIdentity } = require("@dfinity/identity");
const { Principal } = require('@dfinity/principal');

const GRUNT_TO_OPEN = [
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
    "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
    "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
    "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
    "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
    "Curabitur pretium tincidunt lacus, a suscipit velit luctus id.",
    "Integer in diam a magna pharetra venenatis eget at urna.",
    "Etiam at ante auctor, vehicula purus at, aliquet mauris.",
    "Nullam ac sem a purus fringilla vehicula non at urna.",
    "Cras vulputate nulla ut turpis facilisis, eget ultricies odio scelerisque.",
    "Nam consectetur, est id vulputate viverra, felis metus suscipit leo, nec luctus justo elit nec lectus.",
    "In quis lorem at nisl mattis condimentum a non ligula.",
    "Vestibulum tincidunt orci eget erat ultricies, sed lobortis urna vehicula.",
    "Praesent feugiat quam ut turpis finibus, et scelerisque orci lobortis.",
    "Suspendisse faucibus eros et ligula suscipit fermentum.",
    "Donec ultricies justo vitae fermentum sagittis.",
    "Vivamus convallis dui id turpis porttitor, a egestas libero elementum.",
    "Aliquam erat volutpat, suspendisse scelerisque metus at metus suscipit aliquam.",
    "Mauris efficitur purus eget enim finibus, non eleifend velit convallis.",
    "Ut sagittis lacus a ipsum suscipit, nec facilisis lorem faucibus."
];

const NUM_USERS = 10;
const USER_BALANCE = 100_000_000n;
const USER_AVERAGE_GRUNT = 100_000n;
const SCENARIO_DURATION = { 'DAYS': 18n };
const SCENARIO_TICK_DURATION = { 'DAYS': 6n };

const CKBTC_FEE = 10n;

const sleep = (ms) => {
    return new Promise(resolve => setTimeout(resolve, ms));
}

const getRandomUserActor = (userActors) => {
    let randomUser = Math.floor(Math.random() * NUM_USERS);
    let randomUserPrincipal = Array.from(userActors.keys())[randomUser];
    return userActors.get(randomUserPrincipal);
}

const getRandomGrunt = () => {
    return GRUNT_TO_OPEN[Math.floor(Math.random() * GRUNT_TO_OPEN.length)];
}
  
// Example function to call a canister method
async function callCanisterMethod() {
    
    // Import the IDL factory dynamically
    const { idlFactory: protocolFactory } = await import("../../.dfx/local/canisters/protocol/service.did.js");
    const { idlFactory: minterFactory } = await import("../../.dfx/local/canisters/minter/service.did.js");
    const { idlFactory: backendFactory } = await import("../../.dfx/local/canisters/backend/service.did.js");
    const { idlFactory: ckBtcFactory } = await import("../../.dfx/local/canisters/ck_btc/service.did.js");

    // Retrieve canister ID from environment variables
    const protocolCanisterId = process.env.CANISTER_ID_PROTOCOL;
    const minterCanisterId = process.env.CANISTER_ID_MINTER;
    const backendCanisterId = process.env.CANISTER_ID_BACKEND;
    const ckBtcCanisterId = process.env.CANISTER_ID_CK_BTC;

    if (!protocolCanisterId || !backendCanisterId || !minterCanisterId || !ckBtcCanisterId) {
        throw new Error("One of environment variable CANISTER_ID_* is not defined");
    }

    // Simulation actors

    let simIdentity = Ed25519KeyIdentity.generate();

    let protocolActor = await getActor(protocolCanisterId, protocolFactory, simIdentity);
    if (protocolActor === null) {
        throw new Error("Protocol actor is null");
    }

    let backendSimActor = await getActor(backendCanisterId, backendFactory, simIdentity);
    if (backendSimActor === null) {
        throw new Error("BackendSim actor is null");
    }

    let minterActor = await getActor(minterCanisterId, minterFactory, simIdentity);
    if (minterActor === null) {
        throw new Error("ckBTC actor is null");
    }

    // Get user actors for each principal in a Map<Principal, Map<string, Actor>>

    let userActors = new Map();

    for (let i = 0; i < NUM_USERS; i++) {
        let identity = Ed25519KeyIdentity.generate();
        let protocolActor = await getActor(protocolCanisterId, protocolFactory, identity);
        if (protocolActor === null) {
            throw new Error("Protocol actor is null");
        }
        let backendActor = await getActor(backendCanisterId, backendFactory, identity);
        if (backendActor === null) {
            throw new Error("Backend actor is null");
        }
        let ckbtcActor = await getActor(ckBtcCanisterId, ckBtcFactory, identity);
        if (ckbtcActor === null) {
            throw new Error("ckBTC actor is null");
        }
        userActors.set(identity.getPrincipal(), { "protocol": protocolActor, "backend": backendActor, "ckbtc": ckbtcActor });
    }

    // Mint ckBTC to each user
    let mintPromises = [];
    for (let [principal, _] of userActors) {
        mintPromises.push(minterActor.mint({to: { owner: principal, subaccount: [] }, amount: USER_BALANCE}));
    }
    await Promise.all(mintPromises);

    // Approve ckBTC for each user
    let approvePromises = [];
    for (let [_, actors] of userActors) {
        approvePromises.push(actors.ckbtc.icrc2_approve({
            fee: [],
            memo: [],
            from_subaccount: [],
            created_at_time: [],
            amount: USER_BALANCE - CKBTC_FEE,
            expected_allowance: [],
            expires_at: [],
            spender: {
              owner: Principal.fromText(protocolCanisterId),
              subaccount: []
            },
        }));
    }
    await Promise.all(approvePromises);

    // Scenario loop

    var tick = 0n;

    while(tick * toNs(SCENARIO_TICK_DURATION) < toNs(SCENARIO_DURATION)) {

        console.log("Scenario tick: ", tick);

        // A random user opens up a new grunt
        getRandomUserActor(userActors).backend.add_grunt(getRandomGrunt()).then((result) => {
            console.log('New grunt added');
        });

        // Retrieve all grunts
        let grunts = await backendSimActor.get_grunts();
        console.log(grunts);

        let putBallotPromises = [];

        for (let [_, actors] of userActors) {

            for (let grunt of grunts) {

                // 20% chance that this user vote by calling protocolActor.put_ballot
                if (Math.random() < 0.2) {
                    //await sleep(500); // uncomment to not have errors due to duplicate transfers
                    // 50% chance that this user votes YES, 50% chance that this user votes NO
                    putBallotPromises.push(
                        actors.protocol.put_ballot({
                            vote_id: grunt.vote_id,
                            from_subaccount: [],
                            amount: USER_AVERAGE_GRUNT,
                            choice_type: { 'YES_NO': Math.random() < 0.5 ? { 'YES' : null } : { 'NO' : null } }
                        }).then((result) => {
                            if (!result) {
                                console.error('Put ballot result is null');
                            } else if ('err' in result) {
                                console.error('Error putting ballot: ', result.err);
                            }
                        })
                        .catch((error) => {
                            console.error('Error putting ballot: ', error);
                        })
                    );;
                }
            }
        }

        await Promise.all(putBallotPromises);
        await protocolActor.add_time_offset(SCENARIO_TICK_DURATION);
        await protocolActor.try_refund_and_reward();
        tick++;
    }

    protocolActor.get_time_offset().then((result) => {
        console.log('Scenario time offset:', toNs(result));
    });
}

callCanisterMethod();
