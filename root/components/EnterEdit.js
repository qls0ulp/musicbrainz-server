/*
 * @flow
 * Copyright (C) 2018 MetaBrainz Foundation
 *
 * This file is part of MusicBrainz, the open internet music database,
 * and is licensed under the GPL version 2, or (at your option) any
 * later version: http://www.gnu.org/licenses/gpl-2.0.txt
 */

import React from 'react';
import type {Node as ReactNode} from 'react';

import {l} from '../static/scripts/common/i18n';

type Props<F> = {|
  +children: ReactNode,
  +form: FormT<F & {+make_votable: FieldT<boolean>}>,
|};

const EnterEdit = <F>({children, form}: Props<F>) => (
  <>
    <div className="row no-label">
      <div className="auto-editor">
        <label>
          <input
            className="make-votable"
            defaultChecked={form.field.make_votable.value}
            name={form.field.make_votable.html_name}
            type="checkbox"
            value="1"
          />
          {l('Make all edits votable.')}
        </label>
      </div>
    </div>
    <div className="row no-label buttons">
      <button className="submit positive" type="submit">
        {l('Enter edit')}
      </button>
      {children}
    </div>
  </>
);

export default EnterEdit;
