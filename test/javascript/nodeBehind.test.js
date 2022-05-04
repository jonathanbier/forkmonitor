import React from 'react';
import ReactDOM from 'react-dom';

import { mount, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import NodeBehind from 'forkMonitorApp/components/nodeBehind';

let wrapper;

describe('NodeBehind', () => {
  const chaintip = {
    hash: "abcd",
    height: 500000,
    timestamp: 1,
    work: 86.000001
  }

  const node = {
    id: 1,
    name_with_version: "Bitcoin Core 23.0",
    best_block: chaintip,
    unreachable_since: null,
    ibd: false,
    height: 500000 - 2
  };

  beforeAll(() => {
    wrapper = mount(<NodeBehind
      key={ 0 }
      chaintip={ {block: chaintip} }
      node={ node }
      minimum={ 1 }
    />)
  });

  test('should indicate when behind', () => {
    expect(wrapper.text()).toContain(" 2 behind");
  });

});
