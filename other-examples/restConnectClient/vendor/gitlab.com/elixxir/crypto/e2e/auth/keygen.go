////////////////////////////////////////////////////////////////////////////////
// Copyright © 2022 xx foundation                                             //
//                                                                            //
// Use of this source code is governed by a license that can be found in the  //
// LICENSE file.                                                              //
////////////////////////////////////////////////////////////////////////////////

package auth

import (
	jww "github.com/spf13/jwalterweatherman"
	"gitlab.com/elixxir/crypto/cyclic"
	dh "gitlab.com/elixxir/crypto/diffieHellman"
	"gitlab.com/elixxir/crypto/hash"
)

// Const string which gets hashed into the auth key
// to help indicate which operation has been done
var keygenVector = []byte("MakeAuthKey")

// MakeAuthKey generates a one-off key to be used to encrypt payloads
// for an authenticated channel
func MakeAuthKey(myPrivKey, partnerPubKey *cyclic.Int,
	grp *cyclic.Group) (Key []byte, Vector []byte) {
	// Generate the base key for the two users
	baseKey := dh.GenerateSessionKey(myPrivKey, partnerPubKey, grp)

	// Generate the hash function
	h, err := hash.NewCMixHash()
	if err != nil {
		jww.FATAL.Panicf("Could not get hash: %+v", err)
	}

	// Hash the base key, and the vector together
	h.Write(baseKey.Bytes())
	h.Write([]byte(keygenVector))

	// Generate the auth key
	authKey := h.Sum(nil)

	// Reset the hash
	h.Reset()

	// Hash the auth key to generate the vector
	h.Write(authKey)
	authKeyHash := h.Sum(nil)

	// Generate a fingerprint of the vector
	h.Reset()

	return authKey, authKeyHash

}
