////////////////////////////////////////////////////////////////////////////////
// Copyright © 2022 xx foundation                                             //
//                                                                            //
// Use of this source code is governed by a license that can be found in the  //
// LICENSE file.                                                              //
////////////////////////////////////////////////////////////////////////////////

package fact

import (
	"github.com/pkg/errors"
	jww "github.com/spf13/jwalterweatherman"
	"strings"
)

// FactList is a list of Fact. This type can be JSON marshalled and
// unmarshalled.
type FactList []Fact

const factDelimiter = ","
const factBreak = ";"

func (fl FactList) Stringify() string {
	stringList := make([]string, len(fl))
	for index, f := range fl {
		stringList[index] = f.Stringify()
	}

	return strings.Join(stringList, factDelimiter) + factBreak
}

// unstrignifys facts followed by a facts break and with arbatrary data
// atttached at the end
func UnstringifyFactList(s string) (FactList, string, error) {
	parts := strings.SplitN(s, factBreak, 2)
	if len(parts) != 2 {
		return nil, "", errors.New("Invalid fact string passed")
	}
	factStrings := strings.Split(parts[0], factDelimiter)

	var factList []Fact
	for _, fString := range factStrings {
		fact, err := UnstringifyFact(fString)
		if err != nil {
			jww.WARN.Printf("Fact failed to unstringify, dropped: %s",
				err)
		} else {
			factList = append(factList, fact)
		}

	}
	return factList, parts[1], nil
}
