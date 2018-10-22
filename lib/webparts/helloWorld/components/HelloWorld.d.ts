/// <reference types="react" />
import * as React from 'react';
import { IHelloWorldProps } from './IHelloWorldProps';
export default class HelloWorld extends React.Component<IHelloWorldProps, {}> {
    render(): React.ReactElement<IHelloWorldProps>;
}
